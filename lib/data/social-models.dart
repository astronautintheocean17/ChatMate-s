// lib/data/social-models.dart
// Models for the v2 social layer: chat requests, the unified conversation list
// and the two search surfaces.

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.parse(value as String).toLocal();
}

int _parseInt(dynamic value) => (value as num?)?.toInt() ?? 0;

String? _parseHandle(dynamic value) =>
    value == null ? null : (value as String).toLowerCase();

/// A pending 1:1 invitation, either inbound or outbound.
class ChatRequestItem {
  final String requestId;
  final String direction;
  final String handle;
  final String? note;
  final String status;
  final DateTime? createdAt;
  final String? roomId;

  const ChatRequestItem({
    required this.requestId,
    required this.direction,
    required this.handle,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.roomId,
  });

  bool get isIncoming => direction == 'incoming';
  bool get isPending => status == 'pending';

  factory ChatRequestItem.fromMap(Map<String, dynamic> map) => ChatRequestItem(
    requestId: map['request_id'] as String,
    direction: map['direction'] as String? ?? 'incoming',
    handle: (map['handle'] as String? ?? '').toLowerCase(),
    note: map['note'] as String?,
    status: map['status'] as String? ?? 'pending',
    createdAt: _parseDate(map['created_at']),
    roomId: map['room_id'] as String?,
  );
}

/// One row of the WhatsApp-style Chats list: groups and direct chats together.
class ConversationEntry {
  final String id;
  final String kind;
  final String title;
  final String? otherHandle;
  final String code;
  final String visibility;
  final String joinMode;
  final bool openToAll;
  final String role;
  final int memberCount;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String? lastPreview;
  final String? lastKind;
  final String identityMode;

  const ConversationEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.otherHandle,
    required this.code,
    required this.visibility,
    required this.joinMode,
    required this.openToAll,
    required this.role,
    required this.memberCount,
    required this.unreadCount,
    required this.lastMessageAt,
    required this.lastPreview,
    required this.lastKind,
    required this.identityMode,
  });

  bool get isDirect => kind == 'direct';
  bool get isCreator => role == 'creator';
  bool get revealsEveryone => identityMode == 'reveal';
  bool get isAnonymousRoom => identityMode == 'anonymous';

  String get accessMode => joinMode == 'request'
      ? 'request'
      : openToAll
      ? 'all'
      : 'link';

  factory ConversationEntry.fromMap(Map<String, dynamic> map) =>
      ConversationEntry(
        id: map['id'] as String,
        kind: map['kind'] as String? ?? 'group',
        title: map['title'] as String? ?? 'Untitled',
        otherHandle: _parseHandle(map['other_handle']),
        code: map['code'] as String? ?? '',
        visibility: map['visibility'] as String? ?? 'private',
        joinMode: map['join_mode'] == 'open' ? 'open' : 'request',
        openToAll: map['open_to_all'] == true,
        role: map['role'] as String? ?? 'member',
        memberCount: _parseInt(map['member_count']),
        unreadCount: _parseInt(map['unread_count']),
        lastMessageAt: _parseDate(map['last_message_at']),
        lastPreview: map['last_preview'] as String?,
        lastKind: map['last_kind'] as String?,
        identityMode: map['identity_mode'] as String? ?? 'mixed',
      );
}

/// One person behind a reaction: who picked which emoji.
///
/// Only fetched for rooms that already show names — the handle is null when
/// the profile row could not be read.
class MessageReactor {
  final String userId;
  final String emoji;
  final String? handle;
  final String displayName;
  final DateTime? createdAt;

  const MessageReactor({
    required this.userId,
    required this.emoji,
    required this.handle,
    required this.displayName,
    required this.createdAt,
  });

  bool get hasHandle => (handle ?? '').isNotEmpty;

  factory MessageReactor.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'];
    final row = profile is Map
        ? Map<String, dynamic>.from(profile)
        : const <String, dynamic>{};
    return MessageReactor(
      userId: map['user_id'] as String? ?? '',
      emoji: map['emoji'] as String? ?? '',
      handle: _parseHandle(row['handle']),
      displayName: (row['display_name'] as String?) ?? '',
      createdAt: _parseDate(map['created_at']),
    );
  }
}

/// A result of the global ChatMate ID search, with my relationship to it.
class ProfileSearchResult {
  final String id;
  final String handle;
  final String displayName;
  final String relation;
  final String? roomId;

  const ProfileSearchResult({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.relation,
    this.roomId,
  });

  bool get alreadyChatting => relation == 'chat';
  bool get requestPending => relation == 'pending_out';
  bool get requestWaiting => relation == 'pending_in';
  bool get isStranger => relation == 'none';

  factory ProfileSearchResult.fromMap(Map<String, dynamic> map) =>
      ProfileSearchResult(
        id: map['id'] as String,
        handle: (map['handle'] as String? ?? '').toLowerCase(),
        displayName: (map['display_name'] as String?) ?? '',
        relation: map['relation'] as String? ?? 'none',
        roomId: map['room_id'] as String?,
      );
}

/// A result of the Home search: only rooms I belong to and people I chat with.
class HomeSearchEntry {
  final String entry;
  final String id;
  final String title;
  final String subtitle;
  final String? handle;
  final String code;
  final int memberCount;
  final DateTime? lastMessageAt;

  const HomeSearchEntry({
    required this.entry,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.handle,
    required this.code,
    required this.memberCount,
    required this.lastMessageAt,
  });

  bool get isChat => entry == 'chat';

  factory HomeSearchEntry.fromMap(Map<String, dynamic> map) => HomeSearchEntry(
    entry: map['entry'] as String? ?? 'room',
    id: map['id'] as String,
    title: map['title'] as String? ?? '',
    subtitle: map['subtitle'] as String? ?? '',
    handle: _parseHandle(map['handle']),
    code: map['code'] as String? ?? '',
    memberCount: _parseInt(map['member_count']),
    lastMessageAt: _parseDate(map['last_message_at']),
  );
}
