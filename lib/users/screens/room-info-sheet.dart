// lib/users/screens/room-info-sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth-service.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/profile-service.dart';
import '../../data/room-service.dart';
import '../../theme/app-theme.dart';

class RoomInfoSheet extends StatefulWidget {
  const RoomInfoSheet({
    super.key,
    required this.roomId,
    required this.onChanged,
  });

  final String roomId;
  final VoidCallback onChanged;

  @override
  State<RoomInfoSheet> createState() => _RoomInfoSheetState();
}

class _RoomInfoSheetState extends State<RoomInfoSheet> {
  final _nameController = TextEditingController();
  final _inviteController = TextEditingController();
  RoomDetails? _details;
  List<RoomMember> _members = const [];
  List<PendingRoomRequest> _pending = const [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  bool _inviting = false;
  bool _nameInitialized = false;
  String _visibility = 'public';
  String? _busyRequestId;
  String? _removingId;
  String? _error;
  String? _fatal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) AuthService.client.removeChannel(channel);
    _nameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _fatal = null;
      });
    }
    try {
      final details = await RoomService.roomDetails(widget.roomId);
      if (details == null) {
        throw Exception('This room no longer exists, or you are not a member.');
      }
      final members = await RoomService.members(widget.roomId);
      final pending = details.isCreator
          ? await RoomService.pendingRequests(widget.roomId)
          : <PendingRoomRequest>[];
      if (!mounted) return;
      setState(() {
        _details = details;
        _members = members;
        _pending = pending;
        _error = null;
        if (!_nameInitialized) {
          _nameController.text = details.name;
          _visibility = details.visibility;
          _nameInitialized = true;
        }
      });
      _subscribe();
    } catch (error) {
      if (!mounted) return;
      if (_details == null) {
        setState(() => _fatal = friendlyError(error));
      } else {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _load(silent: true);
    } finally {
      _refreshing = false;
    }
  }

  void _subscribe() {
    if (_channel != null || !(_details?.isCreator ?? false)) return;
    final channel = AuthService.client.channel('room-info:${widget.roomId}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'room_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: widget.roomId,
      ),
      callback: (_) => _refresh(),
    );
    channel.subscribe();
    _channel = channel;
  }


  Future<void> _saveRoom() async {
    final details = _details;
    if (details == null || _saving) return;
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _snack('Room name needs at least 2 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await RoomService.updateRoom(
        roomId: widget.roomId,
        name: name,
        visibility: _visibility,
      );
      await _load(silent: true);
      widget.onChanged();
      _snack('Room updated.');
    } catch (error) {
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _invite() async {
    if (_inviting || !(_details?.isCreator ?? false)) return;
    final raw = _inviteController.text.trim().replaceFirst(
          RegExp(r'^@'),
          '',
        );
    final handle = ProfileService.normalizeHandle(raw);
    if (!ProfileService.isValidHandle(handle)) {
      _snack('Handles are 3-24 lowercase letters, numbers or underscores.');
      return;
    }
    setState(() {
      _inviting = true;
      _error = null;
    });
    try {
      await RoomService.inviteMember(
        roomId: widget.roomId,
        handle: handle,
      );
      _inviteController.clear();
      await _load(silent: true);
      _snack('@$handle has an invite waiting.');
    } catch (error) {
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _respond(PendingRoomRequest request, bool accept) async {
    if (_busyRequestId != null) return;
    setState(() => _busyRequestId = request.requestId);
    try {
      await RoomService.respondRequest(
        requestId: request.requestId,
        accept: accept,
      );
      await _load(silent: true);
      widget.onChanged();
      _snack(
        accept
            ? '@${request.handle} is in the room.'
            : request.isInvite
                ? 'Invite to @${request.handle} was cancelled.'
                : '@${request.handle} was declined.',
      );
    } catch (error) {
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _remove(RoomMember member) async {
    if (_removingId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface(dialogContext),
        shape: const RoundedRectangleBorder(),
        title: Text(
          'Remove @${member.handle}?',
          style: AppText.serif(22, color: AppTheme.ink(dialogContext)),
        ),
        content: Text(
          'They lose access to the room immediately. Messages they sent stay '
          'in the conversation.',
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
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _removingId = member.userId);
    try {
      await RoomService.removeMember(
        roomId: widget.roomId,
        userId: member.userId,
      );
      await _load(silent: true);
      widget.onChanged();
      _snack('@${member.handle} was removed.');
    } catch (error) {
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  Future<void> _copyCode() async {
    final code = _details?.code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    _snack('Room code copied.');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.line(context),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ROOM INFO',
                    style: AppText.mono(
                      10,
                      color: AppTheme.muted(context),
                      ls: 1.7,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: AppTheme.accent(context).withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              child: Text(
                _error!,
                style: AppText.body(12, color: AppTheme.accent(context)),
              ),
            ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent(context),
                    ),
                  )
                : _fatal != null
                    ? _buildFatal()
                    : details == null
                        ? const SizedBox.shrink()
                        : RefreshIndicator(
                            color: AppTheme.accent(context),
                            onRefresh: _refresh,
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                6,
                                20,
                                24 + MediaQuery.paddingOf(context).bottom,
                              ),
                              children: [
                                _buildRoomSection(details),
                                const SizedBox(height: 18),
                                _buildCodeSection(details),
                                if (details.isCreator) ...[
                                  const SizedBox(height: 18),
                                  _buildInviteSection(),
                                  const SizedBox(height: 18),
                                  _buildPendingSection(),
                                ],
                                const SizedBox(height: 18),
                                _buildMembersSection(details),
                                const SizedBox(height: 20),
                                Text(
                                  'Messages are always fetched through a '
                                  'membership check. Anonymous senders stay '
                                  'anonymous here too.',
                                  style: AppText.body(
                                    11.5,
                                    color: AppTheme.muted(context),
                                    h: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFatal() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fatal!,
              textAlign: TextAlign.center,
              style: AppText.body(
                13,
                color: AppTheme.muted(context),
                h: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _load(),
              child: const Text('TRY AGAIN'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: AppText.mono(
            9,
            color: AppTheme.muted(context),
            ls: 1.5,
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border.all(color: AppTheme.line(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _buildRoomSection(RoomDetails details) {
    if (!details.isCreator) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('THE ROOM'),
          _card([
            Text(
              details.name,
              style: AppText.serif(26, color: AppTheme.ink(context), h: 1.1),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  details.isPrivate
                      ? Icons.lock_outline_rounded
                      : Icons.public_rounded,
                  size: 14,
                  color: AppTheme.muted(context),
                ),
                const SizedBox(width: 5),
                Text(
                  '${details.isPrivate ? 'PRIVATE' : 'PUBLIC'} · '
                  '${details.memberCount} '
                  '${details.memberCount == 1 ? 'MEMBER' : 'MEMBERS'}',
                  style: AppText.mono(
                    9,
                    color: AppTheme.muted(context),
                    ls: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Created by @${details.creatorHandle}.',
              style: AppText.body(12, color: AppTheme.muted(context)),
            ),
          ]),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('THE ROOM'),
        _card([
          TextField(
            controller: _nameController,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            style: AppText.serif(22, color: AppTheme.ink(context), h: 1.2),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              labelText: 'Room name',
              labelStyle: AppText.mono(
                9,
                color: AppTheme.muted(context),
                ls: 1.2,
              ),
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.line(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accent(context)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('WHO CAN FIND IT'),
          Row(
            children: [
              Expanded(
                child: _visibilityOption(
                  value: 'public',
                  icon: Icons.public_rounded,
                  label: 'PUBLIC',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _visibilityOption(
                  value: 'private',
                  icon: Icons.lock_outline_rounded,
                  label: 'PRIVATE',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _visibility == 'private'
                ? 'Hidden from name search. The code can find it, but joining '
                    'always needs your approval.'
                : 'Findable by name and code. People still need your approval '
                    'before joining.',
            style: AppText.body(
              11.5,
              color: AppTheme.muted(context),
              h: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _saveRoom,
              child: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  : const Text('SAVE CHANGES'),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _visibilityOption({
    required String value,
    required IconData icon,
    required String label,
  }) {
    final selected = _visibility == value;
    final accent = AppTheme.accent(context);
    return InkWell(
      onTap: () => setState(() => _visibility = value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : Colors.transparent,
          border: Border.all(
            color: selected ? accent : AppTheme.line(context),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? accent : AppTheme.muted(context),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppText.mono(
                9.5,
                color: selected ? accent : AppTheme.muted(context),
                ls: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeSection(RoomDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('ROOM CODE'),
        _card([
          Row(
            children: [
              Expanded(
                child: Text(
                  details.code,
                  style: AppText.mono(
                    22,
                    color: AppTheme.ink(context),
                    ls: 4,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: _copyCode,
              ),
            ],
          ),
          Text(
            details.isPrivate
                ? 'Share the code. Joining still needs your approval.'
                : 'Anyone with this code can request to join.',
            style: AppText.body(11.5, color: AppTheme.muted(context)),
          ),
        ]),
      ],
    );
  }



  Widget _buildInviteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('INVITE SOMEONE'),
        _card([
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inviteController,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  onSubmitted: (_) => _invite(),
                  style: AppText.mono(
                    13,
                    color: AppTheme.ink(context),
                    ls: 0.3,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'handle',
                    prefixText: '@',
                    hintStyle: AppText.mono(
                      13,
                      color: AppTheme.muted(context),
                    ),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.line(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppTheme.accent(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _inviting ? null : _invite,
                child: _inviting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      )
                    : const Text('INVITE'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'They need to accept the invite in REQUESTS before they can open '
            'the room.',
            style: AppText.body(
              11.5,
              color: AppTheme.muted(context),
              h: 1.45,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildPendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(
          _pending.isEmpty
              ? 'INVITES & REQUESTS'
              : 'INVITES & REQUESTS (${_pending.length})',
        ),
        _card(
          _pending.isEmpty
              ? [
                  Text(
                    'No pending invites or join requests.',
                    style: AppText.body(
                      12,
                      color: AppTheme.muted(context),
                      h: 1.45,
                    ),
                  ),
                ]
              : [
                  for (var index = 0; index < _pending.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 18,
                        color: AppTheme.line(context),
                      ),
                    _pendingRow(_pending[index]),
                  ],
                ],
        ),
      ],
    );
  }

  Widget _pendingRow(PendingRoomRequest request) {
    final accent = AppTheme.accent(context);
    final busy = _busyRequestId == request.requestId;
    return Row(
      children: [
        _avatar(request.handle),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${request.handle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  13,
                  color: AppTheme.ink(context),
                  w: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                request.isInvite ? 'INVITED BY YOU' : 'WANTS TO JOIN',
                style: AppText.mono(
                  8.5,
                  color: AppTheme.muted(context),
                  ls: 1,
                ),
              ),
            ],
          ),
        ),
        if (busy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: accent,
            ),
          )
        else if (request.isInvite)
          IconButton(
            tooltip: 'Cancel invite',
            onPressed: () => _respond(request, false),
            style: IconButton.styleFrom(
              minimumSize: const Size(34, 34),
              padding: EdgeInsets.zero,
              side: BorderSide(color: AppTheme.line(context)),
            ),
            icon: const Icon(Icons.close_rounded, size: 17),
          )
        else ...[
          IconButton(
            tooltip: 'Accept',
            onPressed: () => _respond(request, true),
            style: IconButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(34, 34),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.check_rounded, size: 17),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Decline',
            onPressed: () => _respond(request, false),
            style: IconButton.styleFrom(
              minimumSize: const Size(34, 34),
              padding: EdgeInsets.zero,
              side: BorderSide(color: AppTheme.line(context)),
            ),
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ],
    );
  }

  Widget _buildMembersSection(RoomDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('MEMBERS (${_members.length})'),
        _card([
          for (var index = 0; index < _members.length; index++) ...[
            if (index > 0)
              Divider(height: 20, color: AppTheme.line(context)),
            _memberRow(_members[index], details),
          ],
        ]),
      ],
    );
  }

  Widget _memberRow(RoomMember member, RoomDetails details) {
    final isMe = member.userId == AuthService.currentUserId;
    final canRemove = details.isCreator && !member.isCreator;
    return Row(
      children: [
        _avatar(member.handle),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '@${member.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    13,
                    color: AppTheme.ink(context),
                    w: FontWeight.w600,
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 5),
                _tag('YOU'),
              ],
            ],
          ),
        ),
        if (member.isCreator) _tag('CREATOR'),
        if (canRemove) ...[
          const SizedBox(width: 4),
          if (_removingId == member.userId)
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppTheme.accent(context),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Remove @${member.handle}',
              onPressed: () => _remove(member),
              icon: Icon(
                Icons.person_remove_outlined,
                size: 18,
                color: AppTheme.muted(context),
              ),
            ),
        ],
      ],
    );
  }

  Widget _avatar(String handle) {
    final initial = handle.isEmpty ? '?' : handle[0].toUpperCase();
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.accent(context).withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppText.mono(
          12,
          color: AppTheme.accent(context),
          w: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.line(context)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          style: AppText.mono(
            7.5,
            color: AppTheme.muted(context),
            ls: 0.8,
          ),
        ),
      );
}

