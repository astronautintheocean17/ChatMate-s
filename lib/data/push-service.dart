// lib/data/push-service.dart
// Firebase Cloud Messaging: permission, token registration and tap routing.
//
// Nothing here is required for the app to work. If Firebase is not configured
// on the platform (for example a web build without a VAPID key, or iOS without
// an APNs key) every call fails soft and the app carries on.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../common/screens/session-gate.dart';
import '../firebase_options.dart';
import '../users/screens/chat-room-screen.dart';
import 'auth-service.dart';
import 'profile-service.dart';
import 'social-service.dart';

/// Set this to the "Web Push certificate" key from
/// Firebase console → Project settings → Cloud Messaging → Web configuration.
/// Web push stays disabled while it is empty.
const String kWebPushVapidKey = '';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

enum PushState { off, ready, denied, unavailable }

/// Required by FCM: must be a top-level function.
@pragma('vm:entry-point')
Future<void> chatmateBackgroundHandler(RemoteMessage message) async {
  // The system already drew the notification. Nothing else to do.
}

class PushService {
  PushService._();

  static final ValueNotifier<PushState> state = ValueNotifier(PushState.off);
  static bool _booted = false;
  static String? _token;
  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _foreground;
  static StreamSubscription<RemoteMessage>? _opened;

  static bool get isReady => state.value == PushState.ready;

  /// Safe to call from main(): never throws.
  static Future<void> boot() async {
    if (_booted) return;
    _booted = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (error) {
      debugPrint('ChatMate push: Firebase unavailable ($error)');
      state.value = PushState.unavailable;
      return;
    }

    if (kIsWeb && kWebPushVapidKey.isEmpty) {
      state.value = PushState.unavailable;
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        state.value = PushState.denied;
        return;
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _foreground = FirebaseMessaging.onMessage.listen(_onForeground);
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
      _refresh = messaging.onRegistered.listen(_onTokenRefresh);

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        // Give the shell a moment to mount before routing.
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          _openFromMessage(initial);
        });
      }

      await syncToken();
    } catch (error) {
      debugPrint('ChatMate push: setup failed ($error)');
      state.value = PushState.unavailable;
    }
  }

  /// Fetches the current FCM token and stores it for the signed-in profile.
  /// Called at boot and again right after a ChatMate ID is created.
  static Future<void> syncToken() async {
    if (state.value == PushState.unavailable) return;
    if (!AuthService.hasSession) return;

    try {
      final messaging = FirebaseMessaging.instance;
      // getToken() is still the only one-shot way to read the current token.
      // ignore: deprecated_member_use
      final token = kIsWeb
          // ignore: deprecated_member_use
          ? await messaging.getToken(vapidKey: kWebPushVapidKey)
          // ignore: deprecated_member_use
          : await messaging.getToken();

      if (token == null || token.isEmpty) return;

      _token = token;
      final profile = await ProfileService.current();
      if (profile == null) {
        // No handle yet: the profile row does not exist, so defer.
        return;
      }

      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';

      await SocialService.registerDeviceToken(token, platform);
      if (state.value != PushState.ready) state.value = PushState.ready;
    } catch (error) {
      debugPrint('ChatMate push: token sync failed ($error)');
    }
  }

  static Future<void> unregisterToken() async {
    final token = _token;
    if (token == null) return;
    try {
      await SocialService.removeDeviceToken(token);
    } catch (_) {
      // Best effort.
    }
  }

  static Future<void> _onTokenRefresh(String token) async {
    _token = token;
    await syncToken();
  }

  static void _onForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    final roomId = message.data['room_id'] as String?;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          notification.title == null
              ? notification.body ?? 'New message'
              : '${notification.title} · ${notification.body ?? ''}',
        ),
        action: roomId == null
            ? null
            : SnackBarAction(
                label: 'OPEN',
                onPressed: () => openRoom(
                  roomId,
                  message.data['room_name'] as String? ?? 'Chat',
                ),
              ),
      ),
    );
  }

  static void _openFromMessage(RemoteMessage message) {
    final roomId = message.data['room_id'] as String?;
    if (roomId == null || roomId.isEmpty) {
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SessionGate()),
        (route) => false,
      );
      return;
    }
    openRoom(roomId, message.data['room_name'] as String? ?? 'Chat');
  }

  static void openRoom(String roomId, String roomName) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(roomId: roomId, roomName: roomName),
      ),
    );
  }

  static Future<void> dispose() async {
    await _refresh?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
  }
}
