import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'comm_notifier.dart';

// Uses classic FCM registration tokens (getToken/onTokenRefresh): the backend
// sends with firebase-admin to these tokens. The newer register()/FID API is
// not supported by firebase-admin yet.
// ignore_for_file: deprecated_member_use

/// Firebase Cloud Messaging — instant notifications even when the app is closed.
///
/// The backend sends a small high-priority "data" push whenever it creates a
/// ping/alert/chat message for this user. The push only wakes the app; the app
/// then runs the same check as the in-app poller ([CommNotifier.runCheck]) and
/// shows the notification, so there is one code path and no duplicates.
///
/// Without android/app/google-services.json Firebase is not configured — every
/// call here is a no-op and the app falls back to polling.
class PushService {
  PushService._();
  static bool _ready = false;
  static String? _token;

  static Future<bool> _initFirebase() async {
    if (kIsWeb) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return true;
    } catch (_) {
      return false; // not configured
    }
  }

  /// Call once the user is logged in.
  static Future<void> start() async {
    if (_ready || !await _initFirebase()) return;
    _ready = true;
    final fm = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    await fm.requestPermission();

    // App open: just refresh (the poller shows the notification)
    FirebaseMessaging.onMessage.listen((_) => CommNotifier.instance.check());
    // Tapped a system notification
    FirebaseMessaging.onMessageOpenedApp.listen((_) => CommNotifier.instance.openComm.value++);
    if (await fm.getInitialMessage() != null) CommNotifier.instance.openComm.value++;

    fm.onTokenRefresh.listen(_register);
    try {
      final t = await fm.getToken();
      if (t != null) await _register(t);
    } catch (_) {}
  }

  static Future<void> _register(String token) async {
    _token = token;
    try {
      await ApiService.instance.post('/comm/devices', body: {'token': token, 'platform': defaultTargetPlatform.name});
    } catch (_) {}
  }

  /// Call on logout, BEFORE the login token is cleared.
  static Future<void> stop() async {
    final t = _token;
    _token = null;
    if (t == null) return;
    try {
      await ApiService.instance.post('/comm/devices/remove', body: {'token': t});
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _ready = false;
  }
}

/// Runs in a background isolate when a push arrives and the app is not in front.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
  try {
    if (await ApiService.instance.isLoggedIn()) {
      await CommNotifier.runCheck(plugin);
      return;
    }
  } catch (_) {/* fall through: show what the push carried */}
  final d = message.data;
  if (d['title'] != null) {
    await plugin.show(
      id: d.hashCode & 0x7fffffff,
      title: '${d['title']}',
      body: '${d['body'] ?? ''}',
      notificationDetails: CommNotifier.details,
      payload: 'comm',
    );
  }
}
