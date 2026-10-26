// lib/data/chat-service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth-service.dart';
import 'models.dart';
import '../media/media-service.dart';

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

  static Future<String> sendMedia({
    required String roomId,
    required String kind,
    required bool revealSender,
    String? mediaPath,
    String? mime,
    int? width,
    int? height,
    String? caption,
    String? stickerId,
    int? durationMs,
  }) async {
    final result = await _client.rpc(
      'send_message',
      params: {
        'p_room_id': roomId,
        'p_body': null,
        'p_reveal_sender': revealSender,
        'p_kind': kind,
        'p_media_path': mediaPath,
        'p_mime': mime,
        'p_width': width,
        'p_height': height,
        'p_caption': caption,
        'p_sticker_id': stickerId,
        'p_duration_ms': durationMs,
      },
    );
    return result as String;
  }

  static Future<void> delete(String messageId, {String? mediaPath}) async {
    await _client.rpc('delete_message', params: {'p_message_id': messageId});
    if (mediaPath != null && mediaPath.isNotEmpty) {
      await MediaService.remove(mediaPath);
    }
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
