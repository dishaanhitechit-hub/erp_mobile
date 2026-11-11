import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'offline_store.dart';

/// A site photo waiting to be uploaded (taken offline or still sending).
class QueuedPhoto {
  final String id;
  final String projectCode;
  final String filePath;
  final Map<String, dynamic> meta; // takenAt, latitude, longitude, accuracy, isMocked, subLocation, caption, source
  final String reportDate; // YYYY-MM-DD (India time)
  int attempts;
  String? lastError;

  QueuedPhoto({
    required this.id,
    required this.projectCode,
    required this.filePath,
    required this.meta,
    required this.reportDate,
    this.attempts = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'projectCode': projectCode, 'filePath': filePath, 'meta': meta,
        'reportDate': reportDate, 'attempts': attempts, 'lastError': lastError,
      };

  static QueuedPhoto fromJson(Map j) => QueuedPhoto(
        id: '${j['id']}',
        projectCode: '${j['projectCode']}',
        filePath: '${j['filePath']}',
        meta: Map<String, dynamic>.from(j['meta'] as Map? ?? {}),
        reportDate: '${j['reportDate']}',
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        lastError: j['lastError'] as String?,
      );
}

/// Site photos are saved on the phone first, then uploaded — right away when
/// there is signal, otherwise as soon as the phone is back online.
class DprQueue extends ChangeNotifier {
  DprQueue._();
  static final instance = DprQueue._();
  static const _key = 'dpr_queue_v1';
  static const uploadPath = '/project-mgmt/dpr/photos';

  final List<QueuedPhoto> items = [];
  bool _loaded = false;
  bool flushing = false;

  /// Bumped after photos reach the server (screens reload).
  final uploaded = ValueNotifier<int>(0);

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/dpr_queue');
    await d.create(recursive: true);
    return d;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        items.addAll((jsonDecode(raw) as List).whereType<Map>().map(QueuedPhoto.fromJson)
            .where((q) => File(q.filePath).existsSync()));
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final q in items) q.toJson()]));
  }

  List<QueuedPhoto> forDay(String projectCode, String day) =>
      items.where((q) => q.projectCode == projectCode && q.reportDate == day).toList();

  /// Keep a stamped photo and try to send it.
  Future<QueuedPhoto> add(Uint8List jpeg, {required String projectCode, required String reportDate, required Map<String, dynamic> meta}) async {
    await load();
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final f = File('${(await _dir()).path}/$id.jpg');
    await f.writeAsBytes(jpeg, flush: true);
    final q = QueuedPhoto(id: id, projectCode: projectCode, filePath: f.path, meta: meta, reportDate: reportDate);
    items.add(q);
    await _save();
    notifyListeners();
    unawaited(flush());
    return q;
  }

  Future<void> remove(QueuedPhoto q) async {
    items.removeWhere((x) => x.id == q.id);
    try {
      await File(q.filePath).delete();
    } catch (_) {}
    await _save();
    notifyListeners();
  }

  /// Upload everything waiting, oldest first; stop at the first network error.
  Future<void> flush() async {
    await load();
    if (flushing || items.isEmpty) return;
    flushing = true;
    notifyListeners();
    var sent = 0;
    try {
      for (final q in [...items]) {
        try {
          await ApiService.instance.uploadFiles(uploadPath, fields: {
            'projectCode': q.projectCode,
            'meta': jsonEncode([q.meta]),
          }, files: [('photos', q.filePath)]);
          await remove(q);
          sent++;
        } on ApiException catch (e) {
          if (e.code == 0 || e.code == 408) break; // still offline
          q.attempts++;
          q.lastError = e.message;
          // "Already uploaded" or rejected for good (no access, not a photo): drop it.
          if (e.code == 400 || e.code == 403 || e.code == 404 || q.attempts >= 5) {
            await remove(q);
          } else {
            await _save();
          }
        }
      }
    } finally {
      flushing = false;
      notifyListeners();
      if (sent > 0) uploaded.value++;
    }
  }

  /// Hook into connectivity: send queued photos whenever the phone is back online.
  void start() {
    load().then((_) => flush());
    NetworkStatus.instance.backOnline.addListener(flush);
  }
}
