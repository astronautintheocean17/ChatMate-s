// test/social_models_test.dart
import 'package:chatmate/data/models.dart';
import 'package:chatmate/data/social-models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage', () {
    Map<String, dynamic> base() => {
      'id': 'msg-1',
      'room_id': 'room-1',
      'body': 'hello https://example.com',
      'created_at': '2026-01-02T03:04:05.000Z',
      'is_mine': false,
      'is_deleted': false,
      'reveal_sender': false,
      'sender_handle': 'NightOwl',
      'seen_count': null,
      'kind': 'text',
    };

    test('parses a plain message', () {
      final message = ChatMessage.fromMap(base());

      expect(message.id, 'msg-1');
      expect(message.text, 'hello https://example.com');
      expect(message.senderHandle, 'nightowl');
      expect(message.hasReply, isFalse);
      expect(message.hasReactions, isFalse);
    });

    test('parses a reply', () {
      final message = ChatMessage.fromMap({
        ...base(),
        'reply_to_id': 'msg-0',
        'reply_preview': 'the original line',
        'reply_handle': 'SomeOne',
      });

      expect(message.hasReply, isTrue);
      expect(message.replyToId, 'msg-0');
      expect(message.replyPreview, 'the original line');
      expect(message.replyHandle, 'someone');
    });

    test('parses reactions with counts and ownership', () {
      final message = ChatMessage.fromMap({
        ...base(),
        'reactions': [
          {'emoji': '👍', 'count': 3, 'mine': true},
          {'emoji': '🔥', 'count': 1, 'mine': false},
        ],
      });

      expect(message.reactions, hasLength(2));
      expect(message.reactions.first.emoji, '👍');
      expect(message.reactions.first.count, 3);
      expect(message.reactions.first.mine, isTrue);
      expect(message.hasReactions, isTrue);
    });

    test('ignores a malformed reactions payload', () {
      final message = ChatMessage.fromMap({...base(), 'reactions': 'nope'});
      expect(message.reactions, isEmpty);
    });

    test('copyWith replaces only reactions', () {
      final message = ChatMessage.fromMap(base());
      final updated = message.copyWith(
        reactions: const [MessageReaction(emoji: '❤️', count: 1, mine: true)],
      );

      expect(updated.id, message.id);
      expect(updated.text, message.text);
      expect(updated.reactions.single.emoji, '❤️');
      expect(message.reactions, isEmpty);
    });
  });

  group('ConversationEntry', () {
    Map<String, dynamic> group() => {
      'id': 'room-1',
      'kind': 'group',
      'title': 'Night shift',
      'other_handle': null,
      'code': 'ABC123',
      'visibility': 'private',
      'join_mode': 'request',
      'open_to_all': false,
      'role': 'creator',
      'member_count': 4,
      'unread_count': 2,
      'last_message_at': '2026-01-02T03:04:05.000Z',
      'last_preview': 'Photo',
      'last_kind': 'image',
      'identity_mode': 'reveal',
    };

    test('parses a group', () {
      final entry = ConversationEntry.fromMap(group());

      expect(entry.isDirect, isFalse);
      expect(entry.isCreator, isTrue);
      expect(entry.revealsEveryone, isTrue);
      expect(entry.unreadCount, 2);
      expect(entry.accessMode, 'request');
    });

    test('parses a direct chat', () {
      final entry = ConversationEntry.fromMap({
        ...group(),
        'kind': 'direct',
        'title': 'nightowl',
        'other_handle': 'NightOwl',
        'identity_mode': 'mixed',
      });

      expect(entry.isDirect, isTrue);
      expect(entry.otherHandle, 'nightowl');
      expect(entry.revealsEveryone, isFalse);
    });
  });

  group('ProfileSearchResult', () {
    test('maps the relation flags', () {
      final result = ProfileSearchResult.fromMap({
        'id': 'p-1',
        'handle': 'Mira',
        'display_name': 'Mira',
        'relation': 'pending_in',
        'room_id': null,
      });

      expect(result.handle, 'mira');
      expect(result.requestWaiting, isTrue);
      expect(result.alreadyChatting, isFalse);
      expect(result.roomId, isNull);
    });
  });

  group('MessageReaction', () {
    test('listFrom drops blank emoji rows', () {
      final list = MessageReaction.listFrom([
        {'emoji': '', 'count': 1, 'mine': true},
        {'emoji': '🔥', 'count': 2, 'mine': false},
      ]);

      expect(list, hasLength(1));
      expect(list.single.emoji, '🔥');
    });
  });
  group('MessageReactor', () {
    test('reads the joined profile and lowercases the handle', () {
      final reactor = MessageReactor.fromMap({
        'user_id': 'u-1',
        'emoji': '🙏',
        'created_at': '2026-01-02T03:04:05.000Z',
        'profiles': {'handle': 'NightOwl', 'display_name': 'Night Owl'},
      });

      expect(reactor.userId, 'u-1');
      expect(reactor.emoji, '🙏');
      expect(reactor.handle, 'nightowl');
      expect(reactor.hasHandle, isTrue);
      expect(reactor.displayName, 'Night Owl');
      expect(reactor.createdAt, isNotNull);
    });

    test('survives a missing profile row', () {
      final reactor = MessageReactor.fromMap({'user_id': 'u-2', 'emoji': '😂'});

      expect(reactor.hasHandle, isFalse);
      expect(reactor.displayName, isEmpty);
      expect(reactor.createdAt, isNull);
    });
  });
}
