import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';
import 'call_service.dart';
import 'comm_api.dart';
import 'push_service.dart';

/// Unread counts for the Communication tab + phone notifications for new
/// pings, alerts and chat messages coming from the web ERP or other phones.
///
///  • App open / in background: checks every [_interval].
///  • App closed: Android WorkManager checks about every 15 minutes
///    (the shortest interval Android allows). Instant delivery to a closed
///    app needs Firebase push (FCM) on the backend.
class CommNotifier extends ChangeNotifier {
  CommNotifier._();
  static final instance = CommNotifier._();

  static const _interval = Duration(seconds: 15);
  static const _bgTask = 'erp-comm-check';
  static const _seenKey = 'comm_seen_v1';

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  bool _ready = false;

  int unreadPings = 0;
  int unreadAlerts = 0;
  int unreadChats = 0;
  int get total => unreadPings + unreadAlerts + unreadChats;

  /// Set when the user taps a notification, so the shell can open the Chats tab.
  final openComm = ValueNotifier<int>(0);

  // ── Setup ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    _ready = true;
    await _initPlugin(_plugin, onTap: (_) => openComm.value++);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) openComm.value++;
    try {
      await Workmanager().initialize(commBackgroundDispatcher);
    } catch (_) {/* not supported on this platform */}
  }

  static Future<void> _initPlugin(FlutterLocalNotificationsPlugin p,
      {void Function(NotificationResponse)? onTap}) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await p.initialize(settings: settings, onDidReceiveNotificationResponse: onTap);
  }

  /// Call after login (and on app start when already logged in).
  Future<void> start() async {
    if (kIsWeb) return;
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    try {
      await Workmanager().registerPeriodicTask(
        _bgTask,
        _bgTask,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => check());
    await check(); // seeds "already seen" before any push can arrive
    CallService.instance.start(); // ringing screen for incoming calls
    unawaited(PushService.start()); // instant push when Firebase is configured
  }

  /// Call on logout while the login token is still valid.
  Future<void> stop() async {
    CallService.instance.stop();
    await PushService.stop();
    _timer?.cancel();
    _timer = null;
    unreadPings = unreadAlerts = unreadChats = 0;
    notifyListeners();
    try {
      await Workmanager().cancelByUniqueName(_bgTask);
    } catch (_) {}
  }

  // ── Checking ─────────────────────────────────────────────────────────────

  /// Refresh counts and show a phone notification for anything new.
  Future<void> check() async {
    if (ApiService.instance.userId == null) return;
    try {
      final r = await runCheck(_plugin);
      unreadPings = r.pings;
      unreadAlerts = r.alerts;
      unreadChats = r.chats;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.code == 401) _timer?.cancel();
    } catch (_) {}
  }

  /// Shared by the foreground timer and the background task.
  /// [ringCalls]: also show a ringing notification for incoming calls (app in
  /// background / closed — in the foreground the call screen opens instead).
  static Future<({int pings, int alerts, int chats})> runCheck(FlutterLocalNotificationsPlugin plugin,
      {bool ringCalls = false}) async {
    if (ringCalls) {
      try {
        await CallService.ringIncoming(plugin);
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final seen = _Seen.load(prefs.getString(_seenKey));
    final firstRun = seen.isEmpty;

    final results = await Future.wait([
      CommApi.notifications(unreadOnly: true),
      CommApi.unreadPingCount(),
      CommApi.conversations(),
    ]);
    final notifs = results[0] as Map<String, dynamic>;
    final pings = results[1] as int;
    final convs = results[2] as List<Map<String, dynamic>>;

    final toShow = <(int, String, String)>[];

    // Alerts (pings create one of these on the backend, so a ping shows here too)
    for (final n in CommApi.items(notifs)) {
      final id = n['id'];
      if (id is! int || seen.alerts.contains(id)) continue;
      seen.alerts.add(id);
      if (n['type'] == 'incoming_call') continue; // calls ring separately (see CallService)
      toShow.add((100000 + id, '${n['title'] ?? 'Notification'}', '${n['body'] ?? ''}'));
    }

    // Chat messages (messages don't create alerts, so watch unread chats)
    var chats = 0;
    for (final c in convs) {
      final unread = (c['unreadCount'] as num? ?? 0).toInt();
      chats += unread;
      final last = c['lastMessage'];
      final key = '${c['conversationId']}';
      final stamp = last is Map ? '${last['sentAt']}' : '';
      if (unread == 0 || c['isMuted'] == true || seen.chats[key] == stamp) {
        if (unread == 0) seen.chats[key] = stamp;
        continue;
      }
      seen.chats[key] = stamp;
      final from = last is Map ? '${last['senderName'] ?? c['name']}' : '${c['name']}';
      final text = last is Map ? '${last['content'] ?? 'Sent an attachment'}' : 'New message';
      final title = c['type'] == 'direct' ? from : '${c['name']} • $from';
      toShow.add((200000 + (c['conversationId'] as int), title, unread > 1 ? '$text  (+${unread - 1} more)' : text));
    }

    seen.trim();
    await prefs.setString(_seenKey, seen.encode());

    // First run after install/login: remember what is already there, don't spam.
    if (!firstRun) {
      for (final (id, title, body) in toShow.take(5)) {
        await plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: details,
          payload: 'comm',
        );
      }
    }
    return (pings: pings, alerts: (notifs['unreadCount'] as num? ?? 0).toInt(), chats: chats);
  }

  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'erp_comm',
      'Messages & pings',
      channelDescription: 'Pings, chat messages and alerts from PRAX ERP',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> clearSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenKey);
  }
}

/// Ids already notified about (stored so foreground + background agree).
class _Seen {
  final Set<int> alerts;
  final Map<String, String> chats;
  _Seen(this.alerts, this.chats);

  bool get isEmpty => alerts.isEmpty && chats.isEmpty;

  static _Seen load(String? raw) {
    try {
      final m = jsonDecode(raw ?? '') as Map<String, dynamic>;
      return _Seen(
        {for (final v in (m['a'] as List? ?? [])) if (v is int) v},
        Map<String, String>.from(m['c'] as Map? ?? {}),
      );
    } catch (_) {
      return _Seen({}, {});
    }
  }

  void trim() {
    if (alerts.length > 500) {
      final keep = (alerts.toList()..sort()).sublist(alerts.length - 300);
      alerts
        ..clear()
        ..addAll(keep);
    }
  }

  String encode() => jsonEncode({'a': alerts.toList(), 'c': chats});
}

/// Runs in a background isolate (WorkManager) while the app is closed.
@pragma('vm:entry-point')
void commBackgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      if (!await ApiService.instance.isLoggedIn()) return true;
      final plugin = FlutterLocalNotificationsPlugin();
      await CommNotifier._initPlugin(plugin);
      await CommNotifier.runCheck(plugin, ringCalls: true);
    } catch (_) {}
    return true;
  });
}
