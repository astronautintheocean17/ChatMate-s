// lib/data/models.dart
// Plain data models for every Supabase RPC used by the app.

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.parse(value as String).toLocal();
}

int _parseInt(dynamic value) => (value as num?)?.toInt() ?? 0;

String _parseJoinMode(dynamic value) => value == 'open' ? 'open' : 'request';

class Profile {
  final String id;
  final String handle;
  final String displayName;

  const Profile({
    required this.id,
    required this.handle,
    required this.displayName,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    final handle = (map['handle'] as String? ?? '').toLowerCase();
    return Profile(
      id: map['id'] as String,
      handle: handle,
      displayName: (map['display_name'] as String?) ?? handle,
    );
  }
}

class RoomSummary {
  final String id;
  final String name;
  final String code;
  final String visibility;
  final String joinMode;
  final bool openToAll;
  final String creatorHandle;
  final String role;
  final int memberCount;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String kind;
  final String identityMode;
  final String? otherHandle;

  const RoomSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.visibility,
    required this.joinMode,
    required this.openToAll,
    required this.creatorHandle,
    required this.role,
    required this.memberCount,
    required this.unreadCount,
    required this.lastMessageAt,
    this.kind = 'group',
    this.identityMode = 'mixed',
    this.otherHandle,
  });

  bool get isCreator => role == 'creator';
  bool get isDirect => kind == 'direct';
  bool get revealsEveryone => identityMode == 'reveal';
  bool get isPrivate => visibility == 'private';
  bool get joinsInstantly => joinMode == 'open';
  bool get isLinkOnly => joinMode == 'open' && !openToAll;
  bool get isOpenToAll => joinMode == 'open' && openToAll;
  String get accessMode => joinMode == 'request'
      ? 'request'
      : openToAll
      ? 'all'
      : 'link';

  factory RoomSummary.fromMap(Map<String, dynamic> map) => RoomSummary(
    id: map['id'] as String,
    name: map['name'] as String,
    code: map['code'] as String,
    visibility: map['visibility'] as String,
    joinMode: _parseJoinMode(map['join_mode']),
    openToAll: map['open_to_all'] == true,
    creatorHandle: (map['creator_handle'] as String? ?? '').toLowerCase(),
    role: map['role'] as String? ?? 'member',
    memberCount: _parseInt(map['member_count']),
    unreadCount: _parseInt(map['unread_count']),
    lastMessageAt: _parseDate(map['last_message_at']),
    kind: map['kind'] as String? ?? 'group',
    identityMode: map['identity_mode'] as String? ?? 'mixed',
    otherHandle: map['other_handle'] == null
        ? null
        : (map['other_handle'] as String).toLowerCase(),
  );
}

class RoomSearchResult {
  final String id;
  final String name;
  final String code;
  final String visibility;
  final String joinMode;
  final bool openToAll;
  final String creatorHandle;
  final int memberCount;
  final bool isMember;
  final String? requestStatus;

  const RoomSearchResult({
    required this.id,
    required this.name,
    required this.code,
    required this.visibility,
    required this.joinMode,
    required this.openToAll,
    required this.creatorHandle,
    required this.memberCount,
    required this.isMember,
    required this.requestStatus,
  });

  bool get isPrivate => visibility == 'private';
  bool get joinsInstantly => joinMode == 'open';
  bool get isLinkOnly => joinMode == 'open' && !openToAll;
  bool get isOpenToAll => joinMode == 'open' && openToAll;
  bool get isPending => requestStatus == 'pending';
  String get accessMode => joinMode == 'request'
      ? 'request'
      : openToAll
      ? 'all'
      : 'link';

  factory RoomSearchResult.fromMap(Map<String, dynamic> map) =>
      RoomSearchResult(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String,
        visibility: map['visibility'] as String,
        joinMode: _parseJoinMode(map['join_mode']),
        openToAll: map['open_to_all'] == true,
        creatorHandle: (map['creator_handle'] as String? ?? '').toLowerCase(),
        memberCount: _parseInt(map['member_count']),
        isMember: map['is_member'] == true,
        requestStatus: map['request_status'] as String?,
      );
}

class RoomDetails {
  final String id;
  final String name;
  final String code;
  final String visibility;
  final String joinMode;
  final bool openToAll;
  final String creatorId;
  final String creatorHandle;
  final int memberCount;
  final String role;
  final DateTime? createdAt;
  final String kind;
  final String identityMode;
  final String? otherHandle;

  const RoomDetails({
    required this.id,
    required this.name,
    required this.code,
    required this.visibility,
    required this.joinMode,
    required this.openToAll,
    required this.creatorId,
    required this.creatorHandle,
    required this.memberCount,
    required this.role,
    required this.createdAt,
    this.kind = 'group',
    this.identityMode = 'mixed',
    this.otherHandle,
  });

  bool get isCreator => role == 'creator';
  bool get isDirect => kind == 'direct';
  bool get forcesAnonymous => identityMode == 'anonymous';
  bool get revealsEveryone => identityMode == 'reveal';
  bool get hasPerMessageReveal => identityMode == 'mixed';
  bool get isPrivate => visibility == 'private';
  bool get joinsInstantly => joinMode == 'open';
  bool get isLinkOnly => joinMode == 'open' && !openToAll;
  bool get isOpenToAll => joinMode == 'open' && openToAll;
  String get accessMode => joinMode == 'request'
      ? 'request'
      : openToAll
      ? 'all'
      : 'link';

  factory RoomDetails.fromMap(Map<String, dynamic> map) => RoomDetails(
    id: map['id'] as String,
    name: map['name'] as String,
    code: map['code'] as String,
    visibility: map['visibility'] as String,
    joinMode: _parseJoinMode(map['join_mode']),
    openToAll: map['open_to_all'] == true,
    creatorId: map['creator_id'] as String,
    creatorHandle: (map['creator_handle'] as String? ?? '').toLowerCase(),
    memberCount: _parseInt(map['member_count']),
    role: map['my_role'] as String? ?? 'member',
    createdAt: _parseDate(map['created_at']),
    kind: map['kind'] as String? ?? 'group',
    identityMode: map['identity_mode'] as String? ?? 'mixed',
    otherHandle: map['other_handle'] == null
        ? null
        : (map['other_handle'] as String).toLowerCase(),
  );
}

class RoomMember {
  final String userId;
  final String handle;
  final String role;
  final DateTime? joinedAt;

  const RoomMember({
    required this.userId,
    required this.handle,
    required this.role,
    required this.joinedAt,
  });

  bool get isCreator => role == 'creator';

  factory RoomMember.fromMap(Map<String, dynamic> map) => RoomMember(
    userId: map['user_id'] as String,
    handle: (map['handle'] as String? ?? '').toLowerCase(),
    role: map['role'] as String? ?? 'member',
    joinedAt: _parseDate(map['joined_at']),
  );
}

class RoomRequestItem {
  final String requestId;
  final String roomId;
  final String roomName;
  final String roomCode;
  final String visibility;
  final int memberCount;
  final String kind;
  final String status;
  final String otherHandle;
  final bool creatorApproved;
  final DateTime? createdAt;

  const RoomRequestItem({
    required this.requestId,
    required this.roomId,
    required this.roomName,
    required this.roomCode,
    required this.visibility,
    required this.memberCount,
    required this.kind,
    required this.status,
    required this.otherHandle,
    required this.creatorApproved,
    required this.createdAt,
  });

  bool get isInvite => kind == 'invite';
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get needsCreatorApproval => isInvite && isPending && !creatorApproved;

  factory RoomRequestItem.fromMap(Map<String, dynamic> map) => RoomRequestItem(
    requestId: map['request_id'] as String,
    roomId: map['room_id'] as String,
    roomName: map['room_name'] as String,
    roomCode: map['room_code'] as String,
    visibility: map['visibility'] as String,
    memberCount: _parseInt(map['member_count']),
    kind: map['kind'] as String,
    status: map['status'] as String,
    otherHandle: (map['other_handle'] as String? ?? '').toLowerCase(),
    creatorApproved: map['creator_approved'] != false,
    createdAt: _parseDate(map['created_at']),
  );
}

class PendingRoomRequest {
  final String requestId;
  final String kind;
  final String handle;
  final String createdByHandle;
  final bool creatorApproved;
  final DateTime? createdAt;

  const PendingRoomRequest({
    required this.requestId,
    required this.kind,
    required this.handle,
    required this.createdByHandle,
    required this.creatorApproved,
    required this.createdAt,
  });

  bool get isInvite => kind == 'invite';
  bool get isAwaitingCreator => isInvite && !creatorApproved;

  factory PendingRoomRequest.fromMap(Map<String, dynamic> map) =>
      PendingRoomRequest(
        requestId: map['request_id'] as String,
        kind: map['kind'] as String,
        handle: (map['user_handle'] as String? ?? '').toLowerCase(),
        createdByHandle: (map['created_by_handle'] as String? ?? '')
            .toLowerCase(),
        creatorApproved: map['creator_approved'] != false,
        createdAt: _parseDate(map['created_at']),
      );
}

class RoomAccessPreview {
  final String id;
  final String name;
  final String code;
  final String visibility;
  final String joinMode;
  final bool openToAll;
  final String creatorHandle;
  final int memberCount;
  final bool isMember;
  final String? requestStatus;
  final String? requestKind;
  final bool creatorApproved;

  const RoomAccessPreview({
    required this.id,
    required this.name,
    required this.code,
    required this.visibility,
    required this.joinMode,
    required this.openToAll,
    required this.creatorHandle,
    required this.memberCount,
    required this.isMember,
    required this.requestStatus,
    required this.requestKind,
    required this.creatorApproved,
  });

  bool get isPrivate => visibility == 'private';
  bool get joinsInstantly => joinMode == 'open';
  bool get isLinkOnly => joinMode == 'open' && !openToAll;
  bool get isOpenToAll => joinMode == 'open' && openToAll;
  bool get isPending => !joinsInstantly && requestStatus == 'pending';
  bool get needsCreatorApproval =>
      isPending && requestKind == 'invite' && !creatorApproved;
  String get accessMode => joinMode == 'request'
      ? 'request'
      : openToAll
      ? 'all'
      : 'link';

  factory RoomAccessPreview.fromMap(Map<String, dynamic> map) =>
      RoomAccessPreview(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String,
        visibility: map['visibility'] as String,
        joinMode: _parseJoinMode(map['join_mode']),
        openToAll: map['open_to_all'] == true,
        creatorHandle: (map['creator_handle'] as String? ?? '').toLowerCase(),
        memberCount: _parseInt(map['member_count']),
        isMember: map['is_member'] == true,
        requestStatus: map['request_status'] as String?,
        requestKind: map['request_kind'] as String?,
        creatorApproved: map['request_creator_approved'] != false,
      );
}

class MessageReaction {
  final String emoji;
  final int count;
  final bool mine;

  const MessageReaction({
    required this.emoji,
    required this.count,
    required this.mine,
  });

  factory MessageReaction.fromMap(Map<String, dynamic> map) => MessageReaction(
    emoji: map['emoji'] as String? ?? '',
    count: _parseInt(map['count']),
    mine: map['mine'] == true,
  );

  static List<MessageReaction> listFrom(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => MessageReaction.fromMap(Map<String, dynamic>.from(row)))
        .where((reaction) => reaction.emoji.isNotEmpty)
        .toList();
  }
}

class ChatMessage {
  final String id;
  final String roomId;
  final String text;
  final DateTime createdAt;
  final bool isMine;
  final bool isDeleted;
  final bool revealSender;
  final String? senderHandle;
  final int? seenCount;
  final String kind;
  final String? mediaPath;
  final String? mime;
  final int? width;
  final int? height;
  final String? caption;
  final String? stickerId;
  final int? durationMs;
  final String? replyToId;
  final String? replyPreview;
  final String? replyHandle;
  final List<MessageReaction> reactions;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.text,
    required this.createdAt,
    required this.isMine,
    required this.isDeleted,
    required this.revealSender,
    required this.senderHandle,
    required this.seenCount,
    this.kind = 'text',
    this.mediaPath,
    this.mime,
    this.width,
    this.height,
    this.caption,
    this.stickerId,
    this.durationMs,
    this.replyToId,
    this.replyPreview,
    this.replyHandle,
    this.reactions = const [],
  });

  bool get hasReply => !isDeleted && replyToId != null;
  bool get hasReactions => !isDeleted && reactions.isNotEmpty;

  bool get isText => !isDeleted && kind == 'text';
  bool get isImage => !isDeleted && kind == 'image';
  bool get isGif => !isDeleted && kind == 'gif';
  bool get isVideo => !isDeleted && kind == 'video';
  bool get isSticker => !isDeleted && kind == 'sticker';
  bool get hasMedia => isImage || isGif || isVideo;
  bool get hasCaption => !isDeleted && (caption ?? '').trim().isNotEmpty;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final kind = map['kind'] as String? ?? 'text';
    return ChatMessage(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      text: (map['body'] as String?) ?? '',
      createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      isMine: map['is_mine'] == true,
      isDeleted: map['is_deleted'] == true,
      revealSender: map['reveal_sender'] == true,
      senderHandle: map['sender_handle'] == null
          ? null
          : (map['sender_handle'] as String).toLowerCase(),
      seenCount: map['seen_count'] == null
          ? null
          : _parseInt(map['seen_count']),
      kind: const {'text', 'image', 'gif', 'video', 'sticker'}.contains(kind)
          ? kind
          : 'text',
      mediaPath: map['media_path'] as String?,
      mime: map['mime'] as String?,
      width: map['width'] == null ? null : _parseInt(map['width']),
      height: map['height'] == null ? null : _parseInt(map['height']),
      caption: map['caption'] as String?,
      stickerId: map['sticker_id'] as String?,
      durationMs: map['duration_ms'] == null
          ? null
          : _parseInt(map['duration_ms']),
      replyToId: map['reply_to_id'] as String?,
      replyPreview: map['reply_preview'] as String?,
      replyHandle: map['reply_handle'] == null
          ? null
          : (map['reply_handle'] as String).toLowerCase(),
      reactions: MessageReaction.listFrom(map['reactions']),
    );
  }

  ChatMessage copyWith({List<MessageReaction>? reactions}) => ChatMessage(
    id: id,
    roomId: roomId,
    text: text,
    createdAt: createdAt,
    isMine: isMine,
    isDeleted: isDeleted,
    revealSender: revealSender,
    senderHandle: senderHandle,
    seenCount: seenCount,
    kind: kind,
    mediaPath: mediaPath,
    mime: mime,
    width: width,
    height: height,
    caption: caption,
    stickerId: stickerId,
    durationMs: durationMs,
    replyToId: replyToId,
    replyPreview: replyPreview,
    replyHandle: replyHandle,
    reactions: reactions ?? this.reactions,
  );
}

class SeenReceipt {
  final int seen;
  final int members;

  const SeenReceipt({required this.seen, required this.members});

  factory SeenReceipt.fromMap(Map<String, dynamic> map) => SeenReceipt(
    seen: _parseInt(map['seen']),
    members: _parseInt(map['members']),
  );
}

class AdminStats {
  final int users;
  final int rooms;
  final int messages;
  final int privateRooms;
  final int publicRooms;

  const AdminStats({
    required this.users,
    required this.rooms,
    required this.messages,
    required this.privateRooms,
    required this.publicRooms,
  });

  factory AdminStats.fromMap(Map<String, dynamic> map) => AdminStats(
    users: _parseInt(map['users']),
    rooms: _parseInt(map['rooms']),
    messages: _parseInt(map['messages']),
    privateRooms: _parseInt(map['private_rooms']),
    publicRooms: _parseInt(map['public_rooms']),
  );
}

class AdminUser {
  final String id;
  final String handle;
  final DateTime? createdAt;
  final int roomCount;
  final int messageCount;

  const AdminUser({
    required this.id,
    required this.handle,
    required this.createdAt,
    required this.roomCount,
    required this.messageCount,
  });

  factory AdminUser.fromMap(Map<String, dynamic> map) => AdminUser(
    id: map['id'] as String,
    handle: (map['handle'] as String? ?? '').toLowerCase(),
    createdAt: _parseDate(map['created_at']),
    roomCount: _parseInt(map['room_count']),
    messageCount: _parseInt(map['message_count']),
  );
}

class AdminRoom {
  final String id;
  final String name;
  final String code;
  final String visibility;
  final String creatorHandle;
  final int memberCount;
  final int messageCount;
  final DateTime? createdAt;

  const AdminRoom({
    required this.id,
    required this.name,
    required this.code,
    required this.visibility,
    required this.creatorHandle,
    required this.memberCount,
    required this.messageCount,
    required this.createdAt,
  });

  bool get isPrivate => visibility == 'private';

  factory AdminRoom.fromMap(Map<String, dynamic> map) => AdminRoom(
    id: map['id'] as String,
    name: map['name'] as String,
    code: map['code'] as String,
    visibility: map['visibility'] as String,
    creatorHandle: (map['creator_handle'] as String? ?? '').toLowerCase(),
    memberCount: _parseInt(map['member_count']),
    messageCount: _parseInt(map['message_count']),
    createdAt: _parseDate(map['created_at']),
  );
}

class AdminRoomSnapshot {
  final Map<String, dynamic> room;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> messages;

  const AdminRoomSnapshot({
    required this.room,
    required this.members,
    required this.requests,
    required this.messages,
  });

  factory AdminRoomSnapshot.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> list(dynamic value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    return AdminRoomSnapshot(
      room: Map<String, dynamic>.from(map['room'] as Map),
      members: list(map['members']),
      requests: list(map['requests']),
      messages: list(map['messages']),
    );
  }
}
