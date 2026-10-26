// lib/data/social-service.dart
// The v2 social layer: private chat requests, the unified conversation list,
// the two search surfaces, reactions, room identity and push tokens.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth-service.dart';
import 'social-models.dart';

class SocialService {
  SocialService._();

  static SupabaseClient get _client => AuthService.client;

  static List<Map<String, dynamic>> _rows(dynamic result) {
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // ─────────────────────── Conversations ───────────────────────

  /// Every room I belong to — direct chats and groups — newest activity first.
  static Future<List<ConversationEntry>> conversations() async {
    final result = await _client.rpc('my_conversations');
    return _rows(result).map(ConversationEntry.fromMap).toList();
  }

  // ─────────────────────── Chat requests ───────────────────────

  static Future<List<ChatRequestItem>> requests() async {
    final result = await _client.rpc('my_chat_requests');
    return _rows(result).map(ChatRequestItem.fromMap).toList();
  }

  static Future<Map<String, dynamic>> startChat(
    String handle, {
    String? note,
  }) async {
    final result = await _client.rpc(
      'start_direct_chat',
      params: {
        'p_handle': handle.trim().toLowerCase(),
        'p_note': (note ?? '').trim().isEmpty ? null : note!.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> respond(
    String requestId, {
    required bool accept,
  }) async {
    final result = await _client.rpc(
      'respond_chat_request',
      params: {'p_request_id': requestId, 'p_accept': accept},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<void> cancelRequest(String requestId) async {
    await _client.rpc(
      'cancel_chat_request',
      params: {'p_request_id': requestId},
    );
  }

  // ─────────────────────── Search ───────────────────────

  /// People I already talk to plus the groups I am in.
  static Future<List<HomeSearchEntry>> homeSearch(String query) async {
    final result = await _client.rpc(
      'home_search',
      params: {'p_query': query.trim()},
    );
    return _rows(result).map(HomeSearchEntry.fromMap).toList();
  }

  /// Keyword search over ChatMate IDs. An empty query returns nothing.
  static Future<List<ProfileSearchResult>> searchProfiles(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final result = await _client.rpc(
      'search_profiles',
      params: {'p_query': trimmed, 'p_limit': 40},
    );
    return _rows(result).map(ProfileSearchResult.fromMap).toList();
  }

  // ─────────────────────── Messages ───────────────────────

  static Future<String> react(String messageId, String emoji) async {
    final result = await _client.rpc(
      'react_message',
      params: {'p_message_id': messageId, 'p_emoji': emoji},
    );
    return (result as Map)['action'] as String? ?? 'set';
  }

  static Future<void> setIdentity(String roomId, String mode) async {
    await _client.rpc(
      'set_room_identity',
      params: {'p_room_id': roomId, 'p_mode': mode},
    );
  }

  // ─────────────────────── Push ───────────────────────

  static Future<void> registerDeviceToken(String token, String platform) async {
    await _client.rpc(
      'register_device_token',
      params: {'p_token': token, 'p_platform': platform},
    );
  }

  static Future<void> removeDeviceToken(String token) async {
    await _client.rpc('remove_device_token', params: {'p_token': token});
  }
}
