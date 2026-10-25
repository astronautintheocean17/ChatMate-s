import 'package:flutter_test/flutter_test.dart';

import 'package:chatmate/common/utils/format.dart';
import 'package:chatmate/data/models.dart';

void main() {
  group('format helpers', () {
    test('clockTime pads hours and minutes', () {
      expect(clockTime(DateTime(2026, 10, 25, 9, 5)), '09:05');
      expect(clockTime(DateTime(2026, 10, 25, 23, 59)), '23:59');
    });

    test('relativeTime covers the short ranges', () {
      final now = DateTime.now();
      expect(relativeTime(now.subtract(const Duration(seconds: 10))), 'just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 5))), '5m ago');
      expect(relativeTime(now.subtract(const Duration(hours: 3))), '3h ago');
    });

    test('shortDate and dayLabel use fixed labels', () {
      expect(shortDate(DateTime(2026, 3, 9)), '2026-03-09');
      expect(dayLabel(DateTime(2026, 3, 9)), 'MON 9 MAR');
    });
  });

  group('ChatMessage.fromMap', () {
    test('reads a revealed message and seen count', () {
      final message = ChatMessage.fromMap({
        'id': 'message-1',
        'room_id': 'room-1',
        'body': 'Hello there',
        'created_at': '2026-10-25T10:00:00.000Z',
        'is_mine': false,
        'is_deleted': false,
        'reveal_sender': true,
        'sender_handle': 'BETA_02',
        'seen_count': 3,
      });

      expect(message.text, 'Hello there');
      expect(message.isMine, isFalse);
      expect(message.isDeleted, isFalse);
      expect(message.revealSender, isTrue);
      expect(message.senderHandle, 'beta_02');
      expect(message.seenCount, 3);
      expect(
        message.createdAt.toUtc(),
        DateTime.utc(2026, 10, 25, 10),
      );
    });

    test('handles a deleted anonymous message', () {
      final message = ChatMessage.fromMap({
        'id': 'message-2',
        'room_id': 'room-1',
        'body': null,
        'created_at': '2026-10-25T10:01:00.000Z',
        'is_mine': true,
        'is_deleted': true,
        'reveal_sender': false,
        'sender_handle': null,
        'seen_count': null,
      });

      expect(message.text, '');
      expect(message.isMine, isTrue);
      expect(message.isDeleted, isTrue);
      expect(message.senderHandle, isNull);
      expect(message.seenCount, isNull);
    });
  });
}
