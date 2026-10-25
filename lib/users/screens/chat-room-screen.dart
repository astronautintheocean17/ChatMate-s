// lib/users/screens/chat-room-screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/utils/format.dart';
import '../../data/auth-service.dart';
import '../../data/chat-service.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/room-service.dart';
import '../../theme/app-theme.dart';
import 'room-info-sheet.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final List<ChatMessage> _messages = [];
  RoomDetails? _details;
  RealtimeChannel? _channel;
  Timer? _typingTimer;
  Timer? _typingReset;
  DateTime? _lastTypingSent;
  bool _loading = true;
  bool _refreshing = false;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _hasMore = false;
  bool _reveal = false;
  bool _someoneTyping = false;
  String? _error;
  String? _fatal;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _typingReset?.cancel();
    final channel = _channel;
    if (channel != null) {
      AuthService.client.removeChannel(channel);
    }
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _fatal = null;
      _error = null;
    });
    try {
      final details = await RoomService.roomDetails(widget.roomId);
      if (details == null) {
        throw Exception('This room no longer exists, or you are not a member.');
      }
      final latest = await ChatService.messages(widget.roomId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _messages
          ..clear()
          ..addAll(latest.reversed);
        _hasMore = latest.length >= 60;
      });
      _subscribe();
      if (_messages.any((message) => !message.isMine)) {
        _markRead(notify: true);
      } else {
        _markRead();
      }
      _scrollToBottom(jump: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _fatal = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    if (_channel != null) return;
    final channel = AuthService.client.channel('room:${widget.roomId}');
    channel
        .onBroadcast(
          event: 'message',
          callback: (_) => _refreshLatest(scroll: true),
        )
        .onBroadcast(
          event: 'typing',
          callback: (_) => _showTyping(),
        )
        .onBroadcast(
          event: 'seen',
          callback: (_) => _refreshLatest(),
        );
    channel.subscribe();
    _channel = channel;
  }

  void _showTyping() {
    if (!mounted) return;
    setState(() => _someoneTyping = true);
    _typingReset?.cancel();
    _typingReset = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _someoneTyping = false);
    });
  }

  Future<void> _refreshLatest({bool scroll = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final latest = await ChatService.messages(widget.roomId);
      if (!mounted) return;
      final previousIds = {for (final message in _messages) message.id};
      final hasNewIncoming = latest.any(
        (message) => !message.isMine && !previousIds.contains(message.id),
      );
      final byId = {for (final message in _messages) message.id: message};
      for (final message in latest) {
        byId[message.id] = message;
      }
      final merged = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final atBottom = !_scroll.hasClients || _scroll.offset < 80;
      setState(() => _messages
        ..clear()
        ..addAll(merged));
      if (scroll || atBottom) _scrollToBottom();
      await _markRead(notify: hasNewIncoming);
    } catch (_) {
      // A transient refresh failure should not wipe visible messages.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final older = await ChatService.messages(
        widget.roomId,
        before: _messages.first.createdAt,
        limit: 50,
      );
      if (!mounted) return;
      final existing = {for (final message in _messages) message.id};
      final fresh =
          older.reversed.where((message) => !existing.contains(message.id));
      setState(() {
        _messages.insertAll(0, fresh);
        _hasMore = older.length >= 50;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }


  Future<void> _markRead({bool notify = false}) async {
    try {
      await ChatService.markRead(widget.roomId);
      if (notify) await _broadcast('seen');
    } catch (_) {
      // Read receipts are best-effort; never block the conversation.
    }
  }

  Future<void> _broadcast(String event) async {
    try {
      await _channel?.sendBroadcastMessage(event: event, payload: const {});
    } catch (_) {
      // Realtime is a convenience; the RPCs remain the source of truth.
    }
  }

  void _onInput(String value) {
    if (value.trim().isEmpty) return;
    final now = DateTime.now();
    final last = _lastTypingSent;
    if (last != null && now.difference(last).inSeconds < 2) return;
    _lastTypingSent = now;
    unawaited(_broadcast('typing'));
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ChatService.send(
        roomId: widget.roomId,
        body: body,
        revealSender: _reveal,
      );
      _input.clear();
      _lastTypingSent = null;
      await _refreshLatest(scroll: true);
      await _broadcast('message');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (jump) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openInfo() async {
    if (_details == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => RoomInfoSheet(
        roomId: widget.roomId,
        onChanged: _reloadRoom,
      ),
    );
    if (mounted) _reloadRoom();
  }

  Future<void> _reloadRoom() async {
    try {
      final details = await RoomService.roomDetails(widget.roomId);
      if (mounted && details != null) setState(() => _details = details);
    } catch (_) {
      // Keep the last known room header if this refresh fails.
    }
  }


  Future<void> _showActions(ChatMessage message) async {
    final isCreator = _details?.isCreator ?? false;
    final canDelete = message.isMine || isCreator;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                children: [
                  Text(
                    message.isMine ? 'YOUR MESSAGE' : 'SENDER',
                    style: AppText.mono(
                      9.5,
                      color: AppTheme.muted(sheetContext),
                      ls: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!message.isMine)
              ListTile(
                leading: Icon(
                  message.senderHandle == null
                      ? Icons.visibility_off_outlined
                      : Icons.alternate_email_rounded,
                  size: 20,
                ),
                title: Text(
                  message.senderHandle == null
                      ? 'Sender stayed anonymous'
                      : 'Sender: @${message.senderHandle}',
                  style: AppText.body(
                    13.5,
                    color: AppTheme.ink(sheetContext),
                  ),
                ),
              ),
            if (message.isMine)
              ListTile(
                leading: const Icon(Icons.done_all_rounded, size: 20),
                title: Text(
                  'Seen by',
                  style: AppText.body(
                    13.5,
                    color: AppTheme.ink(sheetContext),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSeen(message);
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppTheme.accent(sheetContext),
                ),
                title: Text(
                  'Delete message',
                  style: AppText.body(
                    13.5,
                    color: AppTheme.accent(sheetContext),
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(message);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showSeen(ChatMessage message) async {
    try {
      final receipt = await ChatService.seenReceipt(message.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.surface(dialogContext),
          shape: const RoundedRectangleBorder(),
          title: Text(
            'Seen',
            style: AppText.serif(24, color: AppTheme.ink(dialogContext)),
          ),
          content: Text(
            '${receipt.seen} of ${receipt.members} members have read this '
            'message. Names stay private.',
            style: AppText.body(
              13,
              color: AppTheme.muted(dialogContext),
              h: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }


  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface(dialogContext),
        shape: const RoundedRectangleBorder(),
        title: Text(
          'Delete message?',
          style: AppText.serif(24, color: AppTheme.ink(dialogContext)),
        ),
        content: Text(
          'Everyone will see that a message was deleted, but the text is gone.',
          style: AppText.body(
            13,
            color: AppTheme.muted(dialogContext),
            h: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ChatService.delete(message.id);
      await _refreshLatest();
      await _broadcast('message');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              details?.name ?? widget.roomName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.serif(20, color: AppTheme.ink(context), ls: -0.3),
            ),
            if (details != null)
              Text(
                '${details.memberCount} '
                '${details.memberCount == 1 ? 'member' : 'members'}'
                ' · ${details.isPrivate ? 'PRIVATE' : 'PUBLIC'}',
                style: AppText.mono(
                  8.5,
                  color: AppTheme.muted(context),
                  ls: 1.1,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Room info',
            icon: const Icon(Icons.group_outlined, size: 20),
            onPressed: _openInfo,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(details),
    );
  }

  Widget _buildBody(RoomDetails? details) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.accent(context),
        ),
      );
    }
    if (_fatal != null) {
      return _FatalState(
        message: _fatal!,
        onRetry: _bootstrap,
        onBack: () => Navigator.maybePop(context),
      );
    }
    return Column(
      children: [
        if (_error != null) _ErrorBanner(message: _error!),
        Expanded(
          child: _messages.isEmpty ? _EmptyConversation(name: details?.name)
              : RefreshIndicator(
                  color: AppTheme.accent(context),
                  onRefresh: () => _refreshLatest(),
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _messages.length) {
                        return _OlderButton(
                          busy: _loadingOlder,
                          onTap: _loadOlder,
                        );
                      }
                      final message =
                          _messages[_messages.length - 1 - index];
                      return _MessageBubble(
                        message: message,
                        onLongPress: () => _showActions(message),
                        onMore: () => _showActions(message),
                      );
                    },
                  ),
                ),
        ),
        _Composer(
          controller: _input,
          reveal: _reveal,
          sending: _sending,
          someoneTyping: _someoneTyping,
          onRevealChanged: (value) => setState(() => _reveal = value),
          onChanged: _onInput,
          onSend: _send,
        ),
      ],
    );
  }
}



class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onLongPress,
    required this.onMore,
  });

  final ChatMessage message;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final accent = AppTheme.accent(context);
    final foreground = mine ? Colors.white : AppTheme.ink(context);
    final labelColor = mine
        ? Colors.white.withValues(alpha: 0.68)
        : AppTheme.muted(context);
    final text = message.isDeleted ? 'This message was deleted.' : message.text;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(13, 10, 9, 10),
          decoration: BoxDecoration(
            color: mine ? accent : AppTheme.surface(context),
            border: Border.all(
              color: mine ? accent : AppTheme.line(context),
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!message.isDeleted)
                    Icon(
                      mine
                          ? Icons.person_outline_rounded
                          : message.senderHandle == null
                              ? Icons.visibility_off_outlined
                              : Icons.alternate_email_rounded,
                      size: 11,
                      color: labelColor,
                    ),
                  if (!message.isDeleted) const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      message.isDeleted
                          ? dayLabel(message.createdAt)
                          : mine
                              ? 'YOU'
                              : message.senderHandle == null
                                  ? 'ANONYMOUS'
                                  : '@${message.senderHandle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono(
                        8.5,
                        color: labelColor,
                        ls: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    clockTime(message.createdAt),
                    style: AppText.mono(8.5, color: labelColor, ls: 0.4),
                  ),
                  if (!message.isDeleted) ...[
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: onMore,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 15,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                text,
                style: message.isDeleted
                    ? AppText.body(13.5, color: labelColor).copyWith(
                        fontStyle: FontStyle.italic,
                      )
                    : AppText.body(14, color: foreground, h: 1.42),
              ),
              if (mine && !message.isDeleted && (message.seenCount ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.done_all_rounded,
                        size: 12,
                        color: labelColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${message.seenCount} SEEN',
                        style: AppText.mono(
                          8,
                          color: labelColor,
                          ls: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.reveal,
    required this.sending,
    required this.someoneTyping,
    required this.onRevealChanged,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool reveal;
  final bool sending;
  final bool someoneTyping;
  final ValueChanged<bool> onRevealChanged;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.line(context))),
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        7,
        14,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: someoneTyping ? 1 : 0,
                  child: Text(
                    'Someone is typing something...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(8.5, color: accent, ls: 0.6),
                  ),
                ),
              ),
              InkWell(
                onTap: () => onRevealChanged(!reveal),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reveal
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_outlined,
                        size: 12,
                        color: reveal ? accent : AppTheme.muted(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        reveal ? 'HANDLE VISIBLE' : 'STAY ANONYMOUS',
                        style: AppText.mono(
                          8,
                          color: reveal ? accent : AppTheme.muted(context),
                          ls: 0.9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg(context),
                    border: Border.all(color: AppTheme.line(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    style: AppText.body(14, color: AppTheme.ink(context)),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: reveal
                          ? 'Message with your handle...'
                          : 'Message anonymously...',
                      hintStyle: AppText.body(
                        13.5,
                        color: AppTheme.muted(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final active = value.text.trim().isNotEmpty && !sending;
                  return GestureDetector(
                    onTap: active ? onSend : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: active
                            ? accent
                            : AppTheme.muted(context).withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: sending
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.arrow_upward_rounded,
                              size: 19,
                              color: active
                                  ? Colors.white
                                  : AppTheme.muted(context),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _OlderButton extends StatelessWidget {
  const _OlderButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: busy ? null : onTap,
        child: busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppTheme.accent(context),
                ),
              )
            : Text(
                'LOAD EARLIER MESSAGES',
                style: AppText.mono(
                  9,
                  color: AppTheme.accent(context),
                  ls: 1,
                ),
              ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 34,
              color: AppTheme.accent(context),
            ),
            const SizedBox(height: 16),
            Text(
              name == null || name!.isEmpty
                  ? 'Nobody has spoken yet.'
                  : 'Nobody has spoken in $name yet.',
              textAlign: TextAlign.center,
              style: AppText.serif(26, color: AppTheme.ink(context), h: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              'Whatever is said here can stay anonymous. Say the thing.',
              textAlign: TextAlign.center,
              style: AppText.body(
                13,
                color: AppTheme.muted(context),
                h: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.accent(context).withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Text(
        message,
        style: AppText.body(12, color: AppTheme.accent(context)),
      ),
    );
  }
}

class _FatalState extends StatelessWidget {
  const _FatalState({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 34,
              color: AppTheme.accent(context),
            ),
            const SizedBox(height: 16),
            Text(
              'This room is closed to you.',
              textAlign: TextAlign.center,
              style: AppText.serif(26, color: AppTheme.ink(context), h: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body(
                13,
                color: AppTheme.muted(context),
                h: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onBack,
                  child: const Text('BACK'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('TRY AGAIN'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

