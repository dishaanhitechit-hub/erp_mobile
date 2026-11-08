import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/module_registry.dart';
import 'api_service.dart';
import 'comm_api.dart';
import 'offline_store.dart';
import 'record_utils.dart';

/// Downloads everything the user can see in the current project so the app
/// works without internet: every module list, the latest records' details,
/// reports and the communication lists. Responses land in [OfflineStore]
/// through the normal [ApiService.get] path.
class OfflineSync extends ChangeNotifier {
  OfflineSync._();
  static final instance = OfflineSync._();

  static const lastSyncKey = 'offline_last_sync';
  static const _autoEvery = Duration(hours: 6);

  /// Details saved per module (newest first).
  static const detailsPerModule = 20;

  bool running = false;
  double progress = 0; // 0..1
  String step = '';
  DateTime? lastSync;
  String? lastError;

  Future<void> loadLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getInt('${lastSyncKey}_${ApiService.instance.projectCode}') ?? prefs.getInt(lastSyncKey);
    lastSync = t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
    notifyListeners();
  }

  /// Run in the background when the last sync is old. Details only on Wi-Fi.
  Future<void> autoSync() async {
    if (running || ApiService.instance.projectCode == null) return;
    await loadLastSync();
    if (lastSync != null && DateTime.now().difference(lastSync!) < _autoEvery) return;
    final wifi = await NetworkStatus.instance.isWifi();
    await run(details: wifi);
  }

  Future<void> run({bool details = true}) async {
    if (running) return;
    final api = ApiService.instance;
    if (api.projectCode == null) return;
    running = true;
    progress = 0;
    lastError = null;
    step = 'Starting…';
    notifyListeners();

    final modules = [
      for (final s in allSections)
        for (final m in s.modules)
          if (m.available && m.canView) m,
    ];
    final total = modules.length + 1;
    var done = 0;
    var failures = 0;
    void tick(String s) {
      done++;
      progress = (done / total).clamp(0, 1);
      step = s;
      notifyListeners();
    }

    try {
      // Communication: chats, people, pings, alerts, notices.
      step = 'Chats & alerts';
      notifyListeners();
      await Future.wait([
        _safe(CommApi.conversations),
        _safe(CommApi.directory),
        _safe(CommApi.receivedPings),
        _safe(CommApi.sentPings),
        _safe(() => CommApi.notifications()),
        _safe(CommApi.announcements),
        _safe(api.projects),
      ]);
      final convs = await _safe(CommApi.conversations) ?? [];
      await _pool([
        for (final c in convs.take(15))
          if (c['conversationId'] ?? c['id'] case final id?) () => CommApi.messages((id as num).toInt()),
      ]);
      tick('Chats & alerts');
      if (!NetworkStatus.instance.online) throw const OfflineException();

      for (final m in modules) {
        step = m.title;
        notifyListeners();
        try {
          final data = await api.get(m.endpoint!, params: m.params, projectScoped: m.projectScoped);
          if (details && m.detail != null && m.kind == ModuleKind.list) {
            final rows = RecordUtils.extractList(data);
            await _pool([
              for (final r in rows.take(detailsPerModule))
                if (r[m.idKey] != null) () => api.get('${m.detail}/${r[m.idKey]}', projectScoped: false),
            ]);
          }
        } on ApiException catch (e) {
          if (e.code == 0 || e.code == 408) throw const OfflineException();
          failures++; // no access to this one — skip
        }
        tick(m.title);
      }

      lastSync = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(lastSyncKey, lastSync!.millisecondsSinceEpoch);
      await prefs.setInt('${lastSyncKey}_${api.projectCode}', lastSync!.millisecondsSinceEpoch);
      step = failures == 0 ? 'Done' : 'Done ($failures skipped)';
    } on OfflineException {
      lastError = 'No internet — sync stopped. Saved what was downloaded.';
      step = 'Stopped';
    } catch (e) {
      lastError = '$e';
      step = 'Stopped';
    } finally {
      running = false;
      progress = 1;
      notifyListeners();
    }
  }

  static Future<T?> _safe<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  /// Run calls 4 at a time.
  static Future<void> _pool(List<Future<dynamic> Function()> jobs, {int width = 4}) async {
    var i = 0;
    Future<void> worker() async {
      while (i < jobs.length) {
        final job = jobs[i++];
        try {
          await job();
        } on ApiException catch (e) {
          if (e.code == 0 || e.code == 408) rethrow;
        }
      }
    }

    await Future.wait([for (var w = 0; w < width; w++) worker()]);
  }
}
