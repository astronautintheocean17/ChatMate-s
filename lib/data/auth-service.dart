// lib/data/auth-service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static SupabaseClient get client => Supabase.instance.client;
  static const String adminEmailDomain = 'chatmate.app';

  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => currentUser?.id;
  static bool get hasSession => client.auth.currentSession != null;

  static bool get isAdmin {
    final value = currentUser?.appMetadata['is_admin'];
    return value == true || value == 'true';
  }

  /// Normal users have no email/password: an anonymous Supabase session is
  /// created once per device and then reused.
  static Future<User> ensureAnonymousSession() async {
    final existing = currentUser;
    if (existing != null) return existing;
    final response = await client.auth.signInAnonymously();
    final user = response.user;
    if (user == null) {
      throw Exception(
        'Could not start a session. Is Anonymous sign-in enabled?',
      );
    }
    return user;
  }

  /// Admin uses a real email/password account. The UI accepts the short ID
  /// "yourdad" and maps it to yourdad@chatmate.app.
  static Future<User> adminSignIn({
    required String username,
    required String password,
  }) async {
    final trimmed = username.trim().toLowerCase();
    final email = trimmed.contains('@')
        ? trimmed
        : '$trimmed@$adminEmailDomain';

    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    final flag = user?.appMetadata['is_admin'];
    final isAdminUser = flag == true || flag == 'true';
    if (user == null || !isAdminUser) {
      await client.auth.signOut();
      throw Exception('This account is not an admin.');
    }
    return user;
  }

  static Future<void> signOut() => client.auth.signOut();
}
