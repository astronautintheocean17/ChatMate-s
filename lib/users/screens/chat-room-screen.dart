// lib/users/screens/chat-room-screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/utils/format.dart';
import '../../common/widgets/link-text.dart';
import '../../common/widgets/mate-avatar.dart';
import '../../data/auth-service.dart';
import '../../data/chat-service.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/room-service.dart';
import '../../data/social-service.dart';
import '../../media/gif-picker-sheet.dart';
import '../../media/giphy-service.dart';
import '../../media/media-actions.dart';
import '../../media/media-attach-sheet.dart';
import '../../media/media-bubble-content.dart';
import '../../media/media-catalog.dart';
import '../../media/media-preview-sheet.dart';
import '../../media/media-service.dart';
import '../../media/media-viewer-screen.dart';
import '../../media/sticker-picker-sheet.dart';
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
  final Map<String, String> _mediaUrls = {};
  final Map<String, DateTime> _mediaSignedAt = {};
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
  ChatMessage? _replyingTo;
  String? _mediaBusy;
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
      unawaited(_signMedia());
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
        .onBroadcast(event: 'typing', callback: (_) => _showTyping())
        .onBroadcast(event: 'seen', callback: (_) => _refreshLatest())
        .onBroadcast(event: 'reaction', callback: (_) => _refreshLatest());
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
      setState(
        () => _messages
          ..clear()
          ..addAll(merged),
      );
      unawaited(_signMedia());
      if (scroll || atBottom) _scrollToBottom();
      await _markRead(notify: hasNewIncoming);
    } catch (_) {
      // A transient refresh failure should not wipe visible messages.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _signMedia({bool force = false}) async {
    final paths = <String>{
      for (final message in _messages)
        if (message.hasMedia && (message.mediaPath ?? '').isNotEmpty)
          message.mediaPath!,
    };
    if (paths.isEmpty) return;
    final now = DateTime.now();
    final due = paths
        .where((path) {
          final signedAt = _mediaSignedAt[path];
          return force ||
              _mediaUrls[path] == null ||
              signedAt == null ||
              now.difference(signedAt).inMinutes >= 50;
        })
        .toList(growable: false);
    if (due.isEmpty) return;

    final urls = await MediaService.signedUrls(due);
    if (!mounted || urls.isEmpty) return;
    setState(() {
      for (final entry in urls.entries) {
        _mediaUrls[entry.key] = entry.value;
        _mediaSignedAt[entry.key] = now;
      }
    });
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
      final fresh = older.reversed.where(
        (message) => !existing.contains(message.id),
      );
      setState(() {
        _messages.insertAll(0, fresh);
        _hasMore = older.length >= 50;
      });
      unawaited(_signMedia());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
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
        replyTo: _replyingTo?.id,
      );
      _input.clear();
      if (mounted) setState(() => _replyingTo = null);
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

  Future<void> _react(ChatMessage message, String emoji) async {
    // Optimistic: flip the reaction locally so the tap feels instant.
    final existing = message.reactions.firstWhere(
      (reaction) => reaction.mine,
      orElse: () => const MessageReaction(emoji: '', count: 0, mine: false),
    );
    final removing = existing.emoji == emoji;
    final updated = <MessageReaction>[];
    for (final reaction in message.reactions) {
      if (reaction.emoji == emoji) {
        final count =
            reaction.count + (removing ? -1 : (reaction.mine ? 0 : 1));
        if (count > 0) {
          updated.add(
            MessageReaction(emoji: emoji, count: count, mine: !removing),
          );
        }
      } else if (reaction.mine && !removing) {
        final count = reaction.count - 1;
        if (count > 0) {
          updated.add(
            MessageReaction(emoji: reaction.emoji, count: count, mine: false),
          );
        }
      } else {
        updated.add(reaction);
      }
    }
    if (removing && !updated.any((r) => r.emoji == emoji)) {
      // Already handled above.
    } else if (!removing && !updated.any((r) => r.emoji == emoji)) {
      updated.add(MessageReaction(emoji: emoji, count: 1, mine: true));
    }

    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = message.copyWith(
          reactions: List.unmodifiable(updated),
        );
      }
    });

    try {
      await SocialService.react(message.id, emoji);
      await _broadcast('reaction');
    } catch (error) {
      if (mounted) {
        await _refreshLatest();
        _showSnack(error);
      }
    }
  }

  void _startReply(ChatMessage message) {
    setState(() => _replyingTo = message);
  }

  Future<void> _openAttach() async {
    if (_mediaBusy != null || _sending) return;
    final choice = await showMediaAttachSheet(context, includeSticker: false);
    if (choice == null || !mounted) return;
    switch (choice) {
      case AttachChoice.imageCamera:
        await _pickImage(ImageSource.camera);
      case AttachChoice.imageGallery:
        await _pickImage(ImageSource.gallery);
      case AttachChoice.gif:
        await _pickGif();
      case AttachChoice.sticker:
        await _pickSticker();
      case AttachChoice.video:
        final source = await showVideoSourceSheet(context);
        if (source == null || !mounted) return;
        await _pickVideo(
          source == VideoSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
        );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source);
      if (file == null || !mounted) return;
      await _prepareAndPreview(
        () => MediaService.prepareImage(file),
        source == ImageSource.camera
            ? 'PREPARING PHOTO...'
            : 'PREPARING PHOTO...',
      );
    } catch (error) {
      _showSnack(error);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final file = await ImagePicker().pickVideo(
        source: source,
        maxDuration: const Duration(seconds: MediaLimits.maxVideoSeconds),
      );
      if (file == null || !mounted) return;
      await _prepareAndPreview(
        () => MediaService.prepareVideo(file),
        'COMPRESSING VIDEO...',
      );
    } catch (error) {
      _showSnack(error);
    }
  }

  Future<void> _pickGif() async {
    final choice = await showGifPicker(context);
    if (choice == null || !mounted) return;
    if (choice.bundled != null) {
      await _prepareAndPreview(
        () => MediaService.prepareBundledGif(choice.bundled!),
        'PREPARING GIF...',
      );
    } else if (choice.online != null) {
      await _prepareAndPreview(
        () => GiphyService.download(choice.online!),
        'DOWNLOADING GIF...',
      );
    } else if (choice.file != null) {
      await _prepareAndPreview(
        () => MediaService.prepareGif(choice.file!),
        'CHECKING GIF...',
      );
    }
  }

  Future<void> _prepareAndPreview(
    Future<PreparedMedia> Function() prepare,
    String label,
  ) async {
    if (_mediaBusy != null) return;
    setState(() => _mediaBusy = label);
    try {
      final media = await prepare();
      if (!mounted) return;
      setState(() => _mediaBusy = null);
      await showMediaPreview(
        context,
        media: media,
        onSend: (caption) => _sendPrepared(media, caption),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _mediaBusy = null);
      _showSnack(error);
    }
  }

  Future<void> _sendPrepared(PreparedMedia media, String? caption) async {
    String? uploaded;
    try {
      uploaded = await MediaService.upload(roomId: widget.roomId, media: media);
      await ChatService.sendMedia(
        roomId: widget.roomId,
        kind: media.kind,
        revealSender: _reveal,
        mediaPath: uploaded,
        mime: media.mime,
        width: media.width,
        height: media.height,
        caption: caption,
        durationMs: media.durationMs,
        replyTo: _replyingTo?.id,
      );
      if (mounted) setState(() => _replyingTo = null);
      await _refreshLatest(scroll: true);
      await _broadcast('message');
    } catch (error) {
      if (uploaded != null) await MediaService.remove(uploaded);
      rethrow;
    }
  }

  Future<void> _pickSticker() async {
    final item = await showStickerPicker(context);
    if (item == null || !mounted || _mediaBusy != null) return;
    setState(() => _mediaBusy = 'SENDING STICKER...');
    try {
      await ChatService.sendMedia(
        roomId: widget.roomId,
        kind: MediaKind.sticker,
        revealSender: _reveal,
        stickerId: item.id,
        replyTo: _replyingTo?.id,
      );
      if (mounted) setState(() => _replyingTo = null);
      await _refreshLatest(scroll: true);
      await _broadcast('message');
    } catch (error) {
      if (mounted) _showSnack(error);
    } finally {
      if (mounted) setState(() => _mediaBusy = null);
    }
  }

  void _openViewer(ChatMessage message) {
    final path = message.mediaPath;
    final url = path == null ? null : _mediaUrls[path];
    if (url == null) {
      unawaited(_signMedia(force: true));
      _showSnack('That media is still loading. Try again in a moment.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerScreen(message: message, url: url),
      ),
    );
  }

  void _showSnack(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
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
      builder: (_) =>
          RoomInfoSheet(roomId: widget.roomId, onChanged: _reloadRoom),
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
    final mediaPath = message.mediaPath;
    final mediaUrl = mediaPath == null ? null : _mediaUrls[mediaPath];

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
                    message.isMine
                        ? 'YOUR MESSAGE'
                        : message.senderHandle == null
                        ? 'SENDER'
                        : '@${message.senderHandle}',
                    style: AppText.mono(
                      9.5,
                      color: AppTheme.muted(sheetContext),
                      ls: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!message.isDeleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final emoji in const [
                      '👍',
                      '❤️',
                      '😂',
                      '😮',
                      '😢',
                      '🙏',
                      '🔥',
                      '👏',
                    ])
                      InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _react(message, emoji);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                message.reactions.any(
                                  (reaction) =>
                                      reaction.emoji == emoji && reaction.mine,
                                )
                                ? AppTheme.accent(
                                    sheetContext,
                                  ).withValues(alpha: 0.14)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 19),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (!message.isDeleted)
              ListTile(
                leading: const Icon(Icons.reply_rounded, size: 20),
                title: Text(
                  'Reply',
                  style: AppText.body(13.5, color: AppTheme.ink(sheetContext)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startReply(message);
                },
              ),
            if (!message.isDeleted && message.text.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded, size: 20),
                title: Text(
                  'Copy text',
                  style: AppText.body(13.5, color: AppTheme.ink(sheetContext)),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  Navigator.pop(sheetContext);
                },
              ),
            if (message.hasMedia)
              ListTile(
                leading: const Icon(Icons.open_in_full_rounded, size: 20),
                title: Text(
                  'Open ${mediaKindLabel(message).toLowerCase()}',
                  style: AppText.body(13.5, color: AppTheme.ink(sheetContext)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openViewer(message);
                },
              ),
            if (message.hasMedia && mediaUrl != null) ...[
              ListTile(
                leading: const Icon(Icons.download_rounded, size: 20),
                title: Text(
                  'Save to device',
                  style: AppText.body(13.5, color: AppTheme.ink(sheetContext)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  MediaActions.save(context, url: mediaUrl, mime: message.mime);
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded, size: 20),
                title: Text(
                  'Share',
                  style: AppText.body(13.5, color: AppTheme.ink(sheetContext)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  MediaActions.share(
                    context,
                    url: mediaUrl,
                    mime: message.mime,
                  );
                },
              ),
            ],
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
                  style: AppText.body(13.5, color: AppTheme.ink(sheetContext)),
                ),
              ),
            if (message.isMine)
              ListTile(
                leading: const Icon(Icons.done_all_rounded, size: 20),
                title: Text(
                  'Seen by',
                  style: AppText.body(13.5, color: AppTheme.ink(sheetContext)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
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
          style: AppText.body(13, color: AppTheme.muted(dialogContext), h: 1.5),
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
      await ChatService.delete(message.id, mediaPath: message.mediaPath);
      await _refreshLatest();
      await _broadcast('message');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
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
        title: Row(
          children: [
            MateAvatar(
              handle: details?.isDirect == true
                  ? (details?.otherHandle ?? widget.roomName)
                  : (details?.name ?? widget.roomName),
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details?.isDirect == true
                        ? '@${details?.otherHandle ?? 'chat'}'
                        : details?.name ?? widget.roomName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.serif(
                      19,
                      color: AppTheme.ink(context),
                      ls: -0.3,
                    ),
                  ),
                  if (details != null)
                    Text(
                      _headerSubtitle(details),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono(
                        8.5,
                        color: details.revealsEveryone
                            ? AppTheme.accent(context)
                            : AppTheme.muted(context),
                        ls: 1.1,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: details?.isDirect == true ? 'Chat info' : 'Room info',
            icon: Icon(
              details?.isDirect == true
                  ? Icons.info_outline_rounded
                  : Icons.group_outlined,
              size: 20,
            ),
            onPressed: _openInfo,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(details),
    );
  }

  String _headerSubtitle(RoomDetails details) {
    if (details.isDirect) {
      return details.revealsEveryone
          ? 'PRIVATE CHAT · NAMES VISIBLE'
          : 'PRIVATE CHAT · ANONYMOUS BY DEFAULT';
    }
    final identity = details.revealsEveryone
        ? 'NAMES VISIBLE'
        : details.forcesAnonymous
        ? 'ANONYMOUS ONLY'
        : 'REVEAL PER MESSAGE';
    return '${details.memberCount} '
        '${details.memberCount == 1 ? 'MEMBER' : 'MEMBERS'} · $identity';
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
        if (_mediaBusy != null) _MediaBusyBanner(label: _mediaBusy!),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bg(context),
              border: Border(
                top: BorderSide(color: AppTheme.line(context)),
                bottom: BorderSide(color: AppTheme.line(context)),
              ),
            ),
            child: _messages.isEmpty
                ? _EmptyConversation(name: details?.name)
                : RefreshIndicator(
                    color: AppTheme.accent(context),
                    onRefresh: () => _refreshLatest(),
                    child: ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      itemCount: _messages.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _messages.length) {
                          return _OlderButton(
                            busy: _loadingOlder,
                            onTap: _loadOlder,
                          );
                        }
                        final message = _messages[_messages.length - 1 - index];
                        return _MessageBubble(
                          message: message,
                          mediaUrl: message.mediaPath == null
                              ? null
                              : _mediaUrls[message.mediaPath!],
                          onOpen: () => _openViewer(message),
                          onLongPress: () => _showActions(message),
                          onMore: () => _showActions(message),
                          onReact: (emoji) => _react(message, emoji),
                        );
                      },
                    ),
                  ),
          ),
        ),
        _Composer(
          controller: _input,
          reveal: _reveal,
          sending: _sending,
          busy: _mediaBusy != null,
          someoneTyping: _someoneTyping,
          details: details,
          replyingTo: _replyingTo,
          onRevealChanged: (value) => setState(() => _reveal = value),
          onChanged: _onInput,
          onCancelReply: () => setState(() => _replyingTo = null),
          onAttach: _openAttach,
          onSticker: _pickSticker,
          onEmoji: _pickEmoji,
          onSend: _send,
        ),
      ],
    );
  }

  Future<void> _pickEmoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in const [
                '😀',
                '😂',
                '🥹',
                '😍',
                '😎',
                '🤔',
                '😴',
                '🥳',
                '😭',
                '😤',
                '🙃',
                '😅',
                '🤝',
                '🙏',
                '👀',
                '💀',
                '🔥',
                '❤️',
                '✨',
                '🎉',
                '👍',
                '👏',
                '💬',
                '🌙',
              ])
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(sheetContext, item),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Text(item, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (emoji == null || !mounted) return;
    final text = _input.text;
    final selection = _input.selection;
    final at = selection.isValid ? selection.start : text.length;
    _input.text = text.substring(0, at) + emoji + text.substring(at);
    _input.selection = TextSelection.collapsed(offset: at + emoji.length);
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mediaUrl,
    required this.onOpen,
    required this.onLongPress,
    required this.onMore,
    required this.onReact,
  });

  final ChatMessage message;
  final String? mediaUrl;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onMore;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    if (message.isSticker) {
      return _StickerBubble(
        message: message,
        onLongPress: onLongPress,
        onMore: onMore,
      );
    }
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
        onDoubleTap: message.isDeleted ? null : () => onReact('❤️'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: EdgeInsets.fromLTRB(
            message.hasMedia ? 6 : 13,
            message.hasMedia ? 6 : 10,
            9,
            10,
          ),
          decoration: BoxDecoration(
            color: mine ? accent : AppTheme.surface(context),
            border: Border.all(color: mine ? accent : AppTheme.line(context)),
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
                          ? (message.senderHandle == null
                                ? 'YOU'
                                : 'YOU · @${message.senderHandle}')
                          : message.senderHandle == null
                          ? 'ANONYMOUS'
                          : '@${message.senderHandle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono(8.5, color: labelColor, ls: 1.1),
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
              if (message.hasReply)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: mine
                          ? Colors.black.withValues(alpha: 0.18)
                          : AppTheme.bg(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: mine
                              ? Colors.white.withValues(alpha: 0.55)
                              : accent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.replyHandle == null
                              ? 'ANONYMOUS'
                              : '@${message.replyHandle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.mono(
                            8,
                            color: mine
                                ? Colors.white.withValues(alpha: 0.8)
                                : accent,
                            ls: 0.9,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message.replyPreview ?? 'Message',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            11.5,
                            color: mine
                                ? Colors.white.withValues(alpha: 0.85)
                                : AppTheme.muted(context),
                            h: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (message.hasMedia) ...[
                MediaBubbleContent(
                  message: message,
                  url: mediaUrl,
                  onOpen: onOpen,
                ),
                if (message.hasCaption)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 7, 4, 1),
                    child: LinkText(
                      message.caption!,
                      style: AppText.body(13.5, color: foreground, h: 1.4),
                      linkColor: mine ? Colors.white : accent,
                    ),
                  ),
              ] else if (message.isDeleted)
                Text(
                  text,
                  style: AppText.body(
                    13.5,
                    color: labelColor,
                  ).copyWith(fontStyle: FontStyle.italic),
                )
              else
                LinkText(
                  text,
                  style: AppText.body(14, color: foreground, h: 1.45),
                  linkColor: mine ? Colors.white : accent,
                ),
              if (mine && !message.isDeleted && (message.seenCount ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.done_all_rounded, size: 12, color: labelColor),
                      const SizedBox(width: 3),
                      Text(
                        '${message.seenCount} SEEN',
                        style: AppText.mono(8, color: labelColor, ls: 0.8),
                      ),
                    ],
                  ),
                ),
              if (message.hasReactions)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final reaction in message.reactions)
                        InkWell(
                          onTap: () => onReact(reaction.emoji),
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : AppTheme.bg(context),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: mine
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : AppTheme.line(context),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  reaction.emoji,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (reaction.count > 1) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${reaction.count}',
                                    style: AppText.body(
                                      10,
                                      color: foreground,
                                      w: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

class _StickerBubble extends StatelessWidget {
  const _StickerBubble({
    required this.message,
    required this.onLongPress,
    required this.onMore,
  });

  final ChatMessage message;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final sticker = stickerById(message.stickerId);
    final mine = message.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          width: 148,
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (sticker == null)
                Container(
                  width: 128,
                  height: 128,
                  alignment: Alignment.center,
                  color: AppTheme.muted(context).withValues(alpha: 0.1),
                  child: Text(
                    'Sticker unavailable',
                    style: AppText.mono(
                      8,
                      color: AppTheme.muted(context),
                      ls: 0.6,
                    ),
                  ),
                )
              else
                Image.asset(
                  sticker.assetPath,
                  width: 132,
                  height: 132,
                  fit: BoxFit.contain,
                ),
              SizedBox(
                height: 17,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mine
                          ? (message.senderHandle == null
                                ? 'YOU'
                                : 'YOU · @${message.senderHandle}')
                          : message.senderHandle == null
                          ? 'ANONYMOUS'
                          : '@${message.senderHandle}',
                      style: AppText.mono(
                        7.5,
                        color: AppTheme.muted(context),
                        ls: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      clockTime(message.createdAt),
                      style: AppText.mono(
                        7.5,
                        color: AppTheme.muted(context),
                        ls: 0.3,
                      ),
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: onMore,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 13,
                          color: AppTheme.muted(context),
                        ),
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
    required this.busy,
    required this.someoneTyping,
    required this.details,
    required this.replyingTo,
    required this.onRevealChanged,
    required this.onChanged,
    required this.onCancelReply,
    required this.onAttach,
    required this.onSticker,
    required this.onEmoji,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool reveal;
  final bool sending;
  final bool busy;
  final bool someoneTyping;
  final RoomDetails? details;
  final ChatMessage? replyingTo;
  final ValueChanged<bool> onRevealChanged;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancelReply;
  final VoidCallback onAttach;
  final VoidCallback onSticker;
  final VoidCallback onEmoji;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    final canChoose = details?.hasPerMessageReveal ?? true;
    final effectiveReveal = canChoose
        ? reveal
        : (details?.revealsEveryone ?? false);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.line(context))),
      ),
      padding: EdgeInsets.fromLTRB(
        10,
        6,
        10,
        8 + MediaQuery.paddingOf(context).bottom,
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
                    style: AppText.body(
                      10.5,
                      color: accent,
                      w: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (canChoose)
                InkWell(
                  onTap: () => onRevealChanged(!reveal),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: reveal
                          ? accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: reveal
                            ? accent.withValues(alpha: 0.45)
                            : AppTheme.line(context),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          reveal
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_outlined,
                          size: 11,
                          color: reveal ? accent : AppTheme.muted(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reveal ? 'HANDLE VISIBLE' : 'ANONYMOUS',
                          style: AppText.mono(
                            8,
                            color: reveal ? accent : AppTheme.muted(context),
                            ls: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      details?.revealsEveryone == true
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_outlined,
                      size: 11,
                      color: AppTheme.muted(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      details?.revealsEveryone == true
                          ? 'NAMES VISIBLE'
                          : 'ANONYMOUS ONLY',
                      style: AppText.mono(
                        8,
                        color: AppTheme.muted(context),
                        ls: 0.8,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (replyingTo != null)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 6),
              padding: const EdgeInsets.fromLTRB(9, 6, 4, 6),
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: accent, width: 2.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          replyingTo!.isMine
                              ? 'REPLYING TO YOURSELF'
                              : replyingTo!.senderHandle == null
                              ? 'REPLYING TO ANONYMOUS'
                              : 'REPLYING TO @${replyingTo!.senderHandle}',
                          style: AppText.mono(8, color: accent, ls: 0.8),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _replyPreview(replyingTo!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            11.5,
                            color: AppTheme.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: onCancelReply,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _roundButton(
                context,
                icon: Icons.add_rounded,
                tooltip: 'Photo, GIF or video',
                onTap: busy || sending ? null : onAttach,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg(context),
                    border: Border.all(color: AppTheme.line(context)),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    style: AppText.body(14, color: AppTheme.ink(context)),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: effectiveReveal
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
              _roundButton(
                context,
                icon: Icons.emoji_emotions_outlined,
                tooltip: 'Emoji',
                onTap: sending ? null : onEmoji,
              ),
              _roundButton(
                context,
                icon: Icons.sticky_note_2_outlined,
                tooltip: 'Sticker',
                onTap: busy || sending ? null : onSticker,
              ),
              const SizedBox(width: 4),
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

  String _replyPreview(ChatMessage message) {
    if (message.isDeleted) return 'Deleted message';
    if (message.isSticker) return 'Sticker';
    if (message.hasMedia) {
      if (message.hasCaption) return message.caption!.trim();
      if (message.isImage) return 'Photo';
      if (message.isGif) return 'GIF';
      if (message.isVideo) return 'Video';
    }
    return message.text.trim().isEmpty ? 'Message' : message.text.trim();
  }

  Widget _roundButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 21,
        color: onTap == null
            ? AppTheme.muted(context).withValues(alpha: 0.45)
            : AppTheme.accent(context),
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
                style: AppText.mono(9, color: AppTheme.accent(context), ls: 1),
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
              style: AppText.body(13, color: AppTheme.muted(context), h: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaBusyBanner extends StatelessWidget {
  const _MediaBusyBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    return Container(
      width: double.infinity,
      color: accent.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: accent),
          ),
          const SizedBox(width: 9),
          Text(label, style: AppText.mono(8.5, color: accent, ls: 0.9)),
        ],
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
              style: AppText.body(13, color: AppTheme.muted(context), h: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(onPressed: onBack, child: const Text('BACK')),
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
