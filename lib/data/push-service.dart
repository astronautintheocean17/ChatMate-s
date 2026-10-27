// lib/data/push-service.dart
// Firebase Cloud Messaging: permission, token registration and tap routing.
//
// Nothing here is required for the app to work. If Firebase is not configured
// on the platform (for example a web build without a VAPID key, or iOS without
// an APNs key) every call fails soft and the app carries on.
//
// Lifecycle — the order matters:
//   1. main() -> boot(): Firebase, listeners, token for an existing session.
//      It never prompts: an OS permission dialog over a blank first frame is a
//      bug, and on iOS the prompt can only be shown once.
//   2. AppShell mounts -> maybePrompt(): asks once per install, then syncs.
//   3. Profile -> "Push notifications" -> enable(): asks again if allowed.
//   4. Auth changes -> device_tokens follows the signed-in profile.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../common/screens/session-gate.dart';
import '../firebase_options.dart';
import '../users/screens/chat-room-screen.dart';
import '../users/screens/requests-screen.dart';
import 'auth-service.dart';
import 'profile-service.dart';
import 'social-service.dart';

/// Set this to the "Web Push certificate" key from
/// Firebase console → Project settings → Cloud Messaging → Web configuration.
/// Web push stays disabled while it is empty.
const String kWebPushVapidKey = '';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

enum PushState { off, ready, denied, unavailable }

/// Remember that this install was already asked, so ChatMate asks once — not on
/// every launch.
const String _promptedKey = 'chatmate.push.prompted';

/// Required by FCM: must be a top-level function.
@pragma('vm:entry-point')
Future<void> chatmateBackgroundHandler(RemoteMessage message) async {
  // The system already drew the notification. Nothing else to do.
}

class PushService {
  PushService._();

  static final ValueNotifier<PushState> state = ValueNotifier(PushState.off);
  static Future<void>? _booting;
  static String? _token;
  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _foreground;
  static StreamSubscription<RemoteMessage>? _opened;
  static StreamSubscription<AuthState>? _auth;

  static bool get isReady => state.value == PushState.ready;

  static bool get _isApple {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static String get _platformName {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }

  /// Safe to call from main(): never throws, never prompts, safe to call twice.
  static Future<void> boot() => _booting ??= _boot();

  static Future<void> _boot() async {
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

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _foreground = FirebaseMessaging.onMessage.listen(_onForeground);
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
      _refresh = messaging.onRegistered.listen(_onRegistered);

      // One listener keeps device_tokens correct for both cases: a token that
      // rotates, and a profile that appears after this device already booted.
      try {
        _auth = Supabase.instance.client.auth.onAuthStateChange.listen((auth) {
          if (auth.session == null) {
            _token = null;
            return;
          }
          unawaited(syncToken());
        });
      } catch (error) {
        debugPrint('ChatMate push: no auth stream ($error)');
      }

      // A refusal is permanent on Apple platforms: say so instead of silently
      // pretending push is on. Android is asked in enable().
      if (await _permissionRefused()) {
        state.value = PushState.denied;
        return;
      }

      final initial = await messaging.getInitialMessage();
      if (initial != null) unawaited(_openWhenReady(initial));

      await syncToken();
    } catch (error) {
      debugPrint('ChatMate push: setup failed ($error)');
      state.value = PushState.unavailable;
    }
  }

  /// iOS/macOS remember a refusal and never show the prompt twice. Android has
  /// no such state: a permission request simply does not draw a dialog again.
  static Future<bool> _permissionRefused() async {
    if (!_isApple) return false;
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.denied;
    } catch (_) {
      return false;
    }
  }

  /// Called once per install from AppShell, after the first frame.
  static Future<void> maybePrompt() async {
    // No boot() call means nobody started push (unit tests, web without keys):
    // touching the plugin here would only throw.
    if (_booting == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final asked = prefs.getBool(_promptedKey) ?? false;
      if (!asked) {
        await prefs.setBool(_promptedKey, true);
      }
      if (asked) {
        await syncToken();
        return;
      }
    } catch (error) {
      debugPrint('ChatMate push: could not read the prompt flag ($error)');
    }

    await enable();
  }

  /// Asks the OS for permission, then stores the token for the signed-in user.
  /// Returns true when this device can receive notifications right now.
  static Future<bool> enable() async {
    await boot();
    if (state.value == PushState.unavailable) return false;

    try {
      final messaging = FirebaseMessaging.instance;

      if (await _permissionRefused()) {
        state.value = PushState.denied;
        return false;
      }

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        state.value = PushState.denied;
        return false;
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await syncToken();
      return isReady;
    } catch (error) {
      debugPrint('ChatMate push: permission failed ($error)');
      return false;
    }
  }

  /// Fetches the current FCM token and stores it for the signed-in profile.
  /// Called at boot, on permission, and right after a ChatMate ID is created.
  static Future<void> syncToken() async {
    if (state.value == PushState.unavailable) return;

    try {
      if (!AuthService.hasSession) return;
    } catch (_) {
      return; // Supabase not initialised yet.
    }

    try {
      final token = await _currentToken();
      if (token == null || token.isEmpty) return;
      _token = token;

      final profile = await ProfileService.current();
      if (profile == null) {
        // No handle yet: the profile row does not exist, so defer.
        return;
      }

      await SocialService.registerDeviceToken(token, _platformName);
      if (state.value != PushState.denied) state.value = PushState.ready;
    } catch (error) {
      debugPrint('ChatMate push: token sync failed ($error)');
    }
  }

  static Future<String?> _currentToken() async {
    if (_token != null && _token!.isNotEmpty) return _token;

    final messaging = FirebaseMessaging.instance;

    try {
      // v17 API: registers the installation and refreshes onRegistered.
      await messaging.register(
        vapidKey: kIsWeb && kWebPushVapidKey.isNotEmpty
            ? kWebPushVapidKey
            : null,
      );
    } catch (error) {
      debugPrint('ChatMate push: register() failed ($error)');
    }

    try {
      // getToken() is still the only one-shot read; the stream fills the cache.
      // ignore: deprecated_member_use
      final token = kIsWeb
          // ignore: deprecated_member_use
          ? await messaging.getToken(vapidKey: kWebPushVapidKey)
          // ignore: deprecated_member_use
          : await messaging.getToken();
      if (token != null && token.isNotEmpty) _token = token;
    } catch (error) {
      debugPrint('ChatMate push: no token yet ($error)');
    }

    return _token;
  }

  /// Call before AuthService.signOut(): once the session is gone the row can no
  /// longer be deleted under RLS, and the device would keep receiving pushes for
  /// the account that just left.
  static Future<void> signOut() async {
    await unregisterToken();
    _token = null;
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

  static Future<void> _onRegistered(String token) async {
    _token = token;
    await syncToken();
  }

  static void _onForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    final title = notification.title;
    final body = notification.body ?? '';

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(title == null ? body : '$title · $body'),
        action: SnackBarAction(
          label: 'OPEN',
          onPressed: () => _openWhenReady(message),
        ),
      ),
    );
  }

  static void _openFromMessage(RemoteMessage message) {
    unawaited(_openWhenReady(message));
  }

  /// A tap can arrive before the first frame, before the session is restored or
  /// before the shell exists. Wait for all three instead of guessing a delay.
  static Future<void> _openWhenReady(RemoteMessage message) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final navigator = appNavigatorKey.currentState;
      if (navigator != null && _signedIn()) {
        await _route(navigator, message);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    debugPrint('ChatMate push: gave up routing ${message.messageId}');
  }

  static bool _signedIn() {
    try {
      return AuthService.hasSession;
    } catch (_) {
      return false;
    }
  }

  /// Routes by notification type. Requests must open the Requests screen —
  /// sending them to a room id the device does not know yet looked like the app
  /// was restarting itself.
  static Future<void> _route(
    NavigatorState navigator,
    RemoteMessage message,
  ) async {
    final type = _text(message.data['type']) ?? 'message';
    final roomId = _text(message.data['room_id']);
    final roomName = _text(message.data['room_name']) ?? 'Chat';
    final hasRoom = roomId != null && roomId.isNotEmpty;

    switch (type) {
      case 'chat_request':
      case 'chat_declined':
      case 'room_request':
      case 'room_request_response':
        navigator.push(
          MaterialPageRoute(builder: (_) => const RequestsScreen()),
        );
        return;
      case 'chat_accepted':
        if (!hasRoom) {
          navigator.push(
            MaterialPageRoute(builder: (_) => const RequestsScreen()),
          );
          return;
        }
        break;
      default:
        break;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => hasRoom
            ? ChatRoomScreen(roomId: roomId, roomName: roomName)
            : const SessionGate(),
      ),
    );
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Future<void> dispose() async {
    await _refresh?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    await _auth?.cancel();
  }
}
