// lib/main.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase-config.dart';
import 'common/screens/session-gate.dart';
import 'common/screens/setup-required-screen.dart';
import 'data/push-service.dart';
import 'theme/app-theme.dart';
import 'theme/theme-controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.load();

  if (!SupabaseConfig.isConfigured) {
    runApp(const _ConfigApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (error) {
    runApp(_ConfigApp(error: error.toString()));
    return;
  }

  // Push is a bonus layer: Firebase may be absent on web/iOS without keys and
  // the app must still open.
  try {
    FirebaseMessaging.onBackgroundMessage(chatmateBackgroundHandler);
  } catch (_) {
    // Ignore: no Firebase on this platform.
  }
  await PushService.boot();

  runApp(const MyApp());
}

class _ConfigApp extends StatelessWidget {
  final String? error;
  const _ConfigApp({this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: SetupRequiredScreen(error: error),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'ChatMate',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.mode,
          home: const SessionGate(),
        );
      },
    );
  }
}
