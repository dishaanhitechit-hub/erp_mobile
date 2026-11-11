import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'comm_api.dart';
import '../screens/comm/call_screen.dart';

/// Lets the ringing / in-call screens show over the lock screen (and wake the
/// screen) like a phone call. On only while one of them is open, so the ERP is
/// never visible on a locked phone otherwise.
class CallLockScreen {
  static const _ch = MethodChannel('erp/call_screen');
  static int _open = 0;

  static void enter() {
    if (_open++ == 0) _set(true);
  }

  static void leave() {
    if (_open > 0 && --_open == 0) _set(false);
  }

  static void _set(bool on) => _ch.invokeMethod('ringing', on).catchError((_) {});
}

/// Global navigator so a ringing call can open from anywhere in the app.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Watches for incoming calls (from the web ERP or other phones) and opens
/// the ringing screen. Only one call at a time.
class CallService {
  CallService._();
  static final instance = CallService._();

  Timer? _timer;
  bool _checking = false;

  /// Call currently shown (ringing or in progress).
  int? activeCallId;
  final _dismissed = <int>{}; // declined / already handled

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => checkIncoming());
    checkIncoming();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    activeCallId = null;
    _dismissed.clear();
  }

  Future<void> checkIncoming() async {
    if (_checking || activeCallId != null || ApiService.instance.userId == null) return;
    _checking = true;
    try {
      final calls = await CommApi.incomingCalls();
      final call = calls.where((c) => !_dismissed.contains(c['callId'])).firstOrNull;
      if (call != null && activeCallId == null) _showIncoming(call);
    } catch (_) {
    } finally {
      _checking = false;
    }
  }

  void _showIncoming(Map<String, dynamic> call) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    final id = call['callId'] as int;
    activeCallId = id;
    nav.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => IncomingCallScreen(call: call))).whenComplete(() {
      _dismissed.add(id);
      if (activeCallId == id) activeCallId = null;
    });
  }

  /// Start a call to these people and open the call screen.
  Future<void> startCall(BuildContext context, List<Map<String, dynamic>> people, {required bool video}) async {
    final me = ApiService.instance.userId;
    final ids = people.map((p) => (p['userId'] as num).toInt()).where((id) => id != me).toSet().toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No one else to call')));
      return;
    }
    if (activeCallId != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are already in a call')));
      return;
    }
    final nav = Navigator.of(context);
    try {
      final callId = await CommApi.startCall(ids, video: video);
      activeCallId = callId;
      final names = {for (final p in people) (p['userId'] as num).toInt(): '${p['userName'] ?? ''}'};
      await nav.push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(callId: callId, video: video, names: names, outgoing: true),
      ));
      _dismissed.add(callId);
      activeCallId = null;
    } on ApiException catch (e) {
      activeCallId = null;
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Ringing notification (app in background / closed) ──────────────────

  static final _ringChannel = AndroidNotificationDetails(
    'erp_calls',
    'Incoming calls',
    channelDescription: 'Voice and video calls from PRAX ERP',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.call,
    fullScreenIntent: true, // ring over the lock screen like a phone call
    timeoutAfter: 45000,
    ongoing: true,
    autoCancel: true,
    playSound: true,
    sound: const UriAndroidNotificationSound('content://settings/system/ringtone'),
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: keep ringing until answered / timeout
  );

  static int _ringId(int callId) => 300000 + callId;

  /// Show a ringing notification for each incoming call (background check).
  static Future<void> ringIncoming(FlutterLocalNotificationsPlugin plugin) async {
    for (final c in await CommApi.incomingCalls()) {
      await ring(c, plugin);
    }
  }

  /// Ringtone + heads-up notification for one call.
  static Future<void> ring(Map<String, dynamic> c, [FlutterLocalNotificationsPlugin? plugin]) async {
    final id = c['callId'] as int;
    final video = c['callType'] == 'video';
    try {
      await (plugin ?? FlutterLocalNotificationsPlugin()).show(
        id: _ringId(id),
        title: '${c['initiatorName'] ?? 'Someone'} is calling',
        body: video ? 'Incoming video call — tap to answer' : 'Incoming voice call — tap to answer',
        notificationDetails: NotificationDetails(android: _ringChannel),
        payload: 'call:$id',
      );
    } catch (_) {}
  }

  static Future<void> cancelRingNotification(int callId) async {
    try {
      await FlutterLocalNotificationsPlugin().cancel(id: _ringId(callId));
    } catch (_) {}
  }
}
