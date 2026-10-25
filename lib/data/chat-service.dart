// lib/data/chat-service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth-service.dart';
import 'models.dart';

class ChatService {
  ChatService._();

  static SupabaseClient get _client => AuthService.client;

  static Future<List<ChatMessage>> messages(
    String roomId, {
    DateTime? before,
    int limit = 60,
  }) async {
    final result = await _client.rpc(
      'room_messages',
      params: {
        'p_room_id': roomId,
        'p_before': before?.toUtc().toIso8601String(),
        'p_limit': limit,
      },
    );
    return (result as List)
        .whereType<Map>()
        .map((row) => ChatMessage.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<String> send({
    required String roomId,
    required String body,
    required bool revealSender,
  }) async {
    final result = await _client.rpc(
      'send_message',
      params: {
        'p_room_id': roomId,
        'p_body': body,
        'p_reveal_sender': revealSender,
      },
    );
    return result as String;
  }

  static Future<void> delete(String messageId) async {
    await _client.rpc('delete_message', params: {'p_message_id': messageId});
  }

  static Future<void> markRead(String roomId) async {
    await _client.rpc('mark_room_read', params: {'p_room_id': roomId});
  }

  static Future<SeenReceipt> seenReceipt(String messageId) async {
    final result = await _client.rpc(
      'message_seen_count',
      params: {'p_message_id': messageId},
    );
    return SeenReceipt.fromMap(Map<String, dynamic>.from(result as Map));
  }
}
