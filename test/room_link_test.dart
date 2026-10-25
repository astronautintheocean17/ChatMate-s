import 'package:flutter_test/flutter_test.dart';

import 'package:chatmate/data/models.dart';
import 'package:chatmate/data/room-link-service.dart';

void main() {
  group('RoomLinkService', () {
    test('normalizes six-character room codes', () {
      expect(RoomLinkService.normalizeCode(' ab12cd '), 'AB12CD');
      expect(RoomLinkService.normalizeCode('BAD'), isNull);
      expect(RoomLinkService.normalizeCode('ABC12-'), isNull);
    });

    test('reads room codes from query, fragment and path links', () {
      expect(
        RoomLinkService.codeFromUri(
          Uri.parse('https://chatmate.app/?room=ab12cd'),
        ),
        'AB12CD',
      );
      expect(
        RoomLinkService.codeFromUri(
          Uri.parse('https://chatmate.app/#/join/XY12ZW'),
        ),
        'XY12ZW',
      );
      expect(
        RoomLinkService.codeFromUri(
          Uri.parse('https://chatmate.app/join/QR34ST'),
        ),
        'QR34ST',
      );
      expect(
        RoomLinkService.codeFromUri(Uri.parse('https://chatmate.app/')),
        isNull,
      );
    });

    test('builds a share URL while keeping the deployed path', () {
      expect(
        RoomLinkService.linkForCode(
          'ab12cd',
          base: Uri.parse('https://chatmate.app/rooms'),
        ),
        'https://chatmate.app/rooms?room=AB12CD',
      );
    });
  });

  group('room access models', () {
    test('RoomDetails reads join mode from the RPC', () {
      final details = RoomDetails.fromMap({
        'id': 'room-1',
        'name': 'Sunday confessions',
        'code': 'AB12CD',
        'visibility': 'public',
        'join_mode': 'open',
        'open_to_all': false,
        'creator_id': 'user-1',
        'creator_handle': 'ALPHA',
        'member_count': 3,
        'my_role': 'creator',
        'created_at': null,
      });

      expect(details.joinMode, 'open');
      expect(details.joinsInstantly, isTrue);
      expect(details.isLinkOnly, isTrue);
      expect(details.accessMode, 'link');
    });

    test('RoomDetails distinguishes request-only and open-to-all rooms', () {
      RoomDetails details(String mode, String visibility, bool openToAll) =>
          RoomDetails.fromMap({
            'id': 'room-1',
            'name': 'Sunday confessions',
            'code': 'AB12CD',
            'visibility': visibility,
            'join_mode': mode,
            'open_to_all': openToAll,
            'creator_id': 'user-1',
            'creator_handle': 'alpha',
            'member_count': 3,
            'my_role': 'member',
            'created_at': null,
          });

      final requestOnly = details('request', 'private', false);
      expect(requestOnly.joinsInstantly, isFalse);
      expect(requestOnly.accessMode, 'request');

      final openToAll = details('open', 'public', true);
      expect(openToAll.joinsInstantly, isTrue);
      expect(openToAll.isOpenToAll, isTrue);
      expect(openToAll.accessMode, 'all');
    });

    test('RoomRequestItem exposes invites awaiting creator verification', () {
      final item = RoomRequestItem.fromMap({
        'request_id': 'request-1',
        'room_id': 'room-1',
        'room_name': 'Sunday confessions',
        'room_code': 'AB12CD',
        'visibility': 'private',
        'member_count': 3,
        'kind': 'invite',
        'status': 'pending',
        'other_handle': 'BETA',
        'creator_approved': false,
        'created_at': null,
      });

      expect(item.isInvite, isTrue);
      expect(item.needsCreatorApproval, isTrue);
    });

    test('RoomAccessPreview flags unverified invites', () {
      final preview = RoomAccessPreview.fromMap({
        'id': 'room-1',
        'name': 'Sunday confessions',
        'code': 'AB12CD',
        'visibility': 'private',
        'join_mode': 'request',
        'open_to_all': false,
        'creator_handle': 'ALPHA',
        'member_count': 3,
        'is_member': false,
        'request_status': 'pending',
        'request_kind': 'invite',
        'request_creator_approved': false,
      });

      expect(preview.isPending, isTrue);
      expect(preview.needsCreatorApproval, isTrue);
    });

    test('RoomAccessPreview ignores stale pending rows for open links', () {
      final preview = RoomAccessPreview.fromMap({
        'id': 'room-1',
        'name': 'Sunday confessions',
        'code': 'AB12CD',
        'visibility': 'public',
        'join_mode': 'open',
        'open_to_all': false,
        'creator_handle': 'ALPHA',
        'member_count': 3,
        'is_member': false,
        'request_status': 'pending',
        'request_kind': 'join',
        'request_creator_approved': false,
      });

      expect(preview.isPending, isFalse);
      expect(preview.joinsInstantly, isTrue);
      expect(preview.accessMode, 'link');
    });

    test('RoomAccessPreview distinguishes join requests from invites', () {
      final preview = RoomAccessPreview.fromMap({
        'id': 'room-1',
        'name': 'Sunday confessions',
        'code': 'AB12CD',
        'visibility': 'private',
        'join_mode': 'request',
        'open_to_all': false,
        'creator_handle': 'ALPHA',
        'member_count': 3,
        'is_member': false,
        'request_status': 'pending',
        'request_kind': 'join',
        'request_creator_approved': false,
      });

      expect(preview.isPending, isTrue);
      expect(preview.joinsInstantly, isFalse);
      expect(preview.needsCreatorApproval, isFalse);
    });
  });
}
