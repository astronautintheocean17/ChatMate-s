// lib/data/admin-service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth-service.dart';
import 'models.dart';

class AdminService {
  AdminService._();

  static SupabaseClient get _client => AuthService.client;

  static Future<AdminStats> stats() async {
    final result = await _client.rpc('admin_stats');
    return AdminStats.fromMap(Map<String, dynamic>.from(result as Map));
  }

  static Future<List<AdminUser>> users({String query = ''}) async {
    final result = await _client.rpc(
      'admin_list_users',
      params: {'p_query': query.trim()},
    );
    return (result as List)
        .whereType<Map>()
        .map((row) => AdminUser.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<List<AdminRoom>> rooms({String query = ''}) async {
    final result = await _client.rpc(
      'admin_list_rooms',
      params: {'p_query': query.trim()},
    );
    return (result as List)
        .whereType<Map>()
        .map((row) => AdminRoom.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<AdminRoomSnapshot> roomDetails(String roomId) async {
    final result = await _client.rpc(
      'admin_room_details',
      params: {'p_room_id': roomId},
    );
    return AdminRoomSnapshot.fromMap(Map<String, dynamic>.from(result as Map));
  }
}
