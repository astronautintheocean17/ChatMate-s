// lib/data/room-service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth-service.dart';
import 'models.dart';

class RoomService {
  RoomService._();

  static SupabaseClient get _client => AuthService.client;

  static Future<RoomDetails> createRoom({
    required String name,
    required String visibility,
    required String joinMode,
    required bool openToAll,
    required List<String> memberIds,
  }) async {
    final result = await _client.rpc(
      'create_room',
      params: {
        'p_name': name.trim(),
        'p_visibility': visibility,
        'p_join_mode': joinMode,
        'p_open_to_all': openToAll,
        'p_member_ids': memberIds,
      },
    );
    final map = Map<String, dynamic>.from(result as Map);
    final createdId = map['id'] as String;
    final details = await roomDetails(createdId);
    if (details == null) {
      throw Exception('Room was created but could not be loaded.');
    }
    return details;
  }

  static Future<List<RoomSearchResult>> searchRooms(String query) async {
    final result = await _client.rpc(
      'search_rooms',
      params: {'p_query': query.trim()},
    );
    return (result as List)
        .whereType<Map>()
        .map((row) => RoomSearchResult.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<List<RoomSummary>> myRooms() async {
    final result = await _client.rpc('my_rooms');
    return (result as List)
        .whereType<Map>()
        .map((row) => RoomSummary.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<RoomDetails?> roomDetails(String roomId) async {
    final result = await _client.rpc(
      'room_details',
      params: {'p_room_id': roomId},
    );
    if (result == null) return null;
    return RoomDetails.fromMap(Map<String, dynamic>.from(result as Map));
  }

  static Future<RoomAccessPreview?> accessPreview(String code) async {
    final result = await _client.rpc(
      'room_access_preview',
      params: {'p_code': code.trim().toUpperCase()},
    );
    if (result == null) return null;
    return RoomAccessPreview.fromMap(Map<String, dynamic>.from(result as Map));
  }

  static Future<Map<String, dynamic>> joinRoomByCode(String code) async {
    final result = await _client.rpc(
      'join_room_by_code',
      params: {'p_code': code.trim().toUpperCase()},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<List<RoomMember>> members(String roomId) async {
    final result = await _client.rpc(
      'room_members_list',
      params: {'p_room_id': roomId},
    );
    return (result as List)
        .whereType<Map>()
        .map((row) => RoomMember.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<List<RoomRequestItem>> myRequests() async {
    final result = await _client.rpc('my_requests');
    return (result as List)
        .whereType<Map>()
        .map((row) => RoomRequestItem.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<List<PendingRoomRequest>> pendingRequests(String roomId) async {
    final result = await _client.rpc(
      'room_pending_requests',
      params: {'p_room_id': roomId},
    );
    return (result as List)
        .whereType<Map>()
        .map(
          (row) => PendingRoomRequest.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<Map<String, dynamic>> requestJoin(String roomId) async {
    final result = await _client.rpc(
      'request_join',
      params: {'p_room_id': roomId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> respondRequest({
    required String requestId,
    required bool accept,
  }) async {
    final result = await _client.rpc(
      'respond_room_request',
      params: {'p_request_id': requestId, 'p_accept': accept},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> inviteMember({
    required String roomId,
    required String handle,
  }) async {
    final result = await _client.rpc(
      'invite_member',
      params: {'p_room_id': roomId, 'p_handle': handle},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<void> removeMember({
    required String roomId,
    required String userId,
  }) async {
    await _client.rpc(
      'remove_member',
      params: {'p_room_id': roomId, 'p_user_id': userId},
    );
  }

  static Future<void> updateRoom({
    required String roomId,
    required String name,
    required String visibility,
    required String joinMode,
    required bool openToAll,
  }) async {
    await _client.rpc(
      'update_room',
      params: {
        'p_room_id': roomId,
        'p_name': name.trim(),
        'p_visibility': visibility,
        'p_join_mode': joinMode,
        'p_open_to_all': openToAll,
      },
    );
  }
}
