// lib/data/profile-service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth-service.dart';
import 'models.dart';

class ProfileService {
  ProfileService._();

  static SupabaseClient get _client => AuthService.client;

  static String normalizeHandle(String value) => value.trim().toLowerCase();

  static bool isValidHandle(String value) =>
      RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(normalizeHandle(value));

  static Future<Profile?> current() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('id, handle, display_name')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<bool> handleAvailable(String handle) async {
    final normalized = normalizeHandle(handle);
    if (!isValidHandle(normalized)) return false;
    final result = await _client.rpc(
      'handle_available',
      params: {'p_handle': normalized},
    );
    return result == true;
  }

  static Future<Profile> create(String handle) async {
    final result = await _client.rpc(
      'create_profile',
      params: {'p_handle': normalizeHandle(handle)},
    );
    return Profile.fromMap(Map<String, dynamic>.from(result as Map));
  }

  static Future<Profile> changeHandle(String handle) async {
    final result = await _client.rpc(
      'change_handle',
      params: {'p_handle': normalizeHandle(handle)},
    );
    return Profile.fromMap(Map<String, dynamic>.from(result as Map));
  }

  static Future<List<Profile>> search(String query, {int limit = 30}) async {
    final term = query.trim().toLowerCase();
    final userId = AuthService.currentUserId;

    var request = _client.from('profiles').select('id, handle, display_name');
    if (term.isNotEmpty) {
      request = request.ilike('handle', '%$term%');
    }
    final rows = await request
        .neq('id', userId ?? '')
        .order('handle')
        .limit(limit);
    return (rows as List)
        .whereType<Map>()
        .map((row) => Profile.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }
}
