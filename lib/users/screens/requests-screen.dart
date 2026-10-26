// lib/users/screens/requests-screen.dart
// Chat requests: who wants to talk to me, and who I am waiting on.

import 'package:flutter/material.dart';

import '../../common/utils/format.dart';
import '../../common/widgets/mate-avatar.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/room-service.dart';
import '../../data/social-models.dart';
import '../../data/social-service.dart';
import '../../theme/app-theme.dart';
import 'chat-room-screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<ChatRequestItem> _requests = const [];
  List<RoomRequestItem> _invites = const [];
  final Set<String> _busy = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await SocialService.requests();
      List<RoomRequestItem> invites;
      try {
        final all = await RoomService.myRequests();
        invites = all.where((i) => i.isPending).toList();
      } catch (_) {
        invites = const [];
      }
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _invites = invites;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respondRoom(RoomRequestItem invite, bool accept) async {
    setState(() => _busy.add(invite.requestId));
    try {
      await RoomService.respondRequest(
        requestId: invite.requestId,
        accept: accept,
      );
      if (!mounted) return;
      await _load();
      if (!mounted || !accept) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatRoomScreen(roomId: invite.roomId, roomName: invite.roomName),
        ),
      );
      if (mounted) _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy.remove(invite.requestId));
    }
  }

  Future<void> _respond(ChatRequestItem request, bool accept) async {
    setState(() => _busy.add(request.requestId));
    try {
      final result = await SocialService.respond(
        request.requestId,
        accept: accept,
      );
      if (!mounted) return;
      if (accept && result['status'] == 'accepted') {
        final roomId = result['room_id'] as String?;
        await _load();
        if (!mounted || roomId == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ChatRoomScreen(roomId: roomId, roomName: '@${request.handle}'),
          ),
        );
        if (mounted) _load();
        return;
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy.remove(request.requestId));
    }
  }

  Future<void> _cancel(ChatRequestItem request) async {
    setState(() => _busy.add(request.requestId));
    try {
      await SocialService.cancelRequest(request.requestId);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy.remove(request.requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final incoming = _requests.where((r) => r.isIncoming).toList();
    final outgoing = _requests.where((r) => !r.isIncoming).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: Text(
          'Requests',
          style: AppText.serif(22, color: AppTheme.ink(context), ls: -0.5),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.accent(context),
        child: _body(incoming, outgoing),
      ),
    );
  }

  Widget _body(List<ChatRequestItem> incoming, List<ChatRequestItem> outgoing) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.accent(context),
        ),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: AppText.body(13, color: AppTheme.muted(context)),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('TRY AGAIN')),
        ],
      );
    }

    if (_requests.isEmpty && _invites.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 90, 32, 20),
        children: [
          Icon(
            Icons.mark_chat_read_outlined,
            size: 34,
            color: AppTheme.accent(context),
          ),
          const SizedBox(height: 16),
          Text(
            'All clear.',
            textAlign: TextAlign.center,
            style: AppText.serif(24, color: AppTheme.ink(context)),
          ),
          const SizedBox(height: 8),
          Text(
            'No one is waiting on you, and you are not waiting on anyone.',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppTheme.muted(context), h: 1.6),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_invites.isNotEmpty) ...[
          _sectionLabel('ROOM INVITES'),
          ..._invites.map(_inviteCard),
        ],
        if (incoming.isNotEmpty) ...[
          if (_invites.isNotEmpty) const SizedBox(height: 18),
          _sectionLabel('WAITING ON YOU'),
          ...incoming.map((request) => _card(request, incoming: true)),
        ],
        if (outgoing.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionLabel('SENT'),
          ...outgoing.map((request) => _card(request, incoming: false)),
        ],
      ],
    );
  }

  Widget _inviteCard(RoomRequestItem invite) {
    final busy = _busy.contains(invite.requestId);
    final waiting = invite.needsCreatorApproval;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.accent(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.groups_2_outlined,
                  size: 20,
                  color: AppTheme.accent(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        15,
                        color: AppTheme.ink(context),
                        w: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invite.otherHandle.isEmpty
                          ? '${invite.memberCount} member${invite.memberCount == 1 ? '' : 's'}'
                          : '@${invite.otherHandle} invited you',
                      style: AppText.body(10.5, color: AppTheme.muted(context)),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                ),
            ],
          ),
          if (waiting) ...[
            const SizedBox(height: 10),
            Text(
              'The creator still has to approve this invite.',
              style: AppText.body(11.5, color: AppTheme.muted(context)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _respondRoom(invite, false),
                  child: const Text('DECLINE'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy || waiting
                      ? null
                      : () => _respondRoom(invite, true),
                  child: const Text('JOIN'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      text,
      style: AppText.mono(9.5, color: AppTheme.muted(context), ls: 1.4),
    ),
  );

  Widget _card(ChatRequestItem request, {required bool incoming}) {
    final busy = _busy.contains(request.requestId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MateAvatar(handle: request.handle, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${request.handle}',
                      style: AppText.body(
                        15,
                        color: AppTheme.ink(context),
                        w: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      relativeTime(request.createdAt),
                      style: AppText.body(10.5, color: AppTheme.muted(context)),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                ),
            ],
          ),
          if ((request.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.note!.trim(),
                style: AppText.body(12.5, color: AppTheme.ink(context), h: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (incoming)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _respond(request, false),
                    child: const Text('DECLINE'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _respond(request, true),
                    child: const Text('ACCEPT'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 13,
                  color: AppTheme.muted(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Waiting for @${request.handle}',
                    style: AppText.body(11.5, color: AppTheme.muted(context)),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => _cancel(request),
                  child: Text(
                    'CANCEL',
                    style: AppText.mono(9.5, color: AppTheme.muted(context)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
