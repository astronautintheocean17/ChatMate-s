// lib/users/screens/room-invite-screen.dart
import 'package:flutter/material.dart';

import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/room-service.dart';
import '../../theme/app-theme.dart';
import 'chat-room-screen.dart';
import 'home-screen.dart';

/// The ID-gated landing screen for a shared room link.
///
/// Nobody is admitted from the link itself. The link only lets a signed-in
/// person ask the creator for access (or open a room they already belong to).
class RoomInviteScreen extends StatefulWidget {
  const RoomInviteScreen({super.key, required this.code});

  final String code;

  @override
  State<RoomInviteScreen> createState() => _RoomInviteScreenState();
}

class _RoomInviteScreenState extends State<RoomInviteScreen> {
  RoomAccessPreview? _preview;
  bool _loading = true;
  bool _busy = false;
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
      final preview = await RoomService.accessPreview(widget.code);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        if (preview == null) {
          _error = 'This invite link is invalid or the room no longer exists.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestAccess() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await RoomService.joinRoomByCode(widget.code);
      if (!mounted) return;
      if (result['status'] == 'member') {
        await _openRoom();
        return;
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent. The room creator has to approve you.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRoom() async {
    final preview = _preview;
    if (preview == null) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            ChatRoomScreen(roomId: preview.id, roomName: preview.name),
      ),
    );
  }

  Future<void> _goHome() async {
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'CHATMATE',
                        style: AppText.mono(
                          11,
                          color: AppTheme.accent(context),
                          ls: 2.6,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ROOM INVITE',
                        style: AppText.mono(
                          9,
                          color: AppTheme.muted(context),
                          ls: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    _buildError()
                  else if (_preview != null)
                    _buildPreview(_preview!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border.all(color: AppTheme.line(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link unavailable.',
            style: AppText.serif(30, color: AppTheme.ink(context)),
          ),
          const SizedBox(height: 10),
          Text(
            _error!,
            style: AppText.body(13, color: AppTheme.muted(context), h: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton(onPressed: _load, child: const Text('TRY AGAIN')),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _goHome,
                child: const Text('BACK TO CHATMATE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(RoomAccessPreview preview) {
    final awaitingCreator = preview.needsCreatorApproval;
    final pending = preview.isPending;
    final primaryLabel = preview.isMember
        ? 'OPEN ROOM'
        : pending
        ? awaitingCreator
              ? 'WAITING FOR CREATOR'
              : 'BACK TO CHATMATE'
        : preview.isOpenJoin
        ? 'ASK TO JOIN'
        : 'REQUEST TO JOIN';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border.all(color: AppTheme.line(context)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                preview.isPrivate
                    ? Icons.lock_outline_rounded
                    : Icons.public_rounded,
                size: 14,
                color: AppTheme.muted(context),
              ),
              const SizedBox(width: 6),
              Text(
                '${preview.isPrivate ? 'PRIVATE' : 'PUBLIC'} · '
                '${preview.isOpenJoin ? 'OPEN LINK' : 'REQUEST ONLY'}',
                style: AppText.mono(9, color: AppTheme.muted(context), ls: 1),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent(context).withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  preview.code,
                  style: AppText.mono(
                    10,
                    color: AppTheme.accent(context),
                    ls: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            preview.name,
            style: AppText.serif(36, color: AppTheme.ink(context), h: 1.02),
          ),
          const SizedBox(height: 10),
          Text(
            'Created by @${preview.creatorHandle} · ${preview.memberCount} '
            '${preview.memberCount == 1 ? 'member' : 'members'}',
            style: AppText.body(12.5, color: AppTheme.muted(context)),
          ),
          const SizedBox(height: 22),
          Text(
            _statusCopy(preview),
            style: AppText.body(
              13,
              color: awaitingCreator
                  ? AppTheme.accent(context)
                  : AppTheme.muted(context),
              h: 1.55,
            ),
          ),
          if (pending && !awaitingCreator) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.line(context)),
              ),
              child: Text(
                'You can check REQUESTS on your home screen for updates.',
                style: AppText.body(
                  11.5,
                  color: AppTheme.muted(context),
                  h: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : pending && !preview.isMember
                  ? (awaitingCreator ? null : _goHome)
                  : preview.isMember
                  ? _openRoom
                  : _requestAccess,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent(context),
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.line(
                  context,
                ).withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.7,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      primaryLabel,
                      style: AppText.mono(10, color: Colors.white, ls: 1.3),
                    ),
            ),
          ),
          if (!pending || preview.isMember || awaitingCreator) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy ? null : _goHome,
                child: Text(
                  'BACK TO CHATMATE',
                  style: AppText.mono(
                    9,
                    color: AppTheme.muted(context),
                    ls: 1.1,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            'Access is approved by the room creator. A link never bypasses '
            'that.',
            style: AppText.body(10.5, color: AppTheme.muted(context), h: 1.4),
          ),
        ],
      ),
    );
  }

  String _statusCopy(RoomAccessPreview preview) {
    if (preview.isMember) {
      return 'You are already a member of this room.';
    }
    if (preview.needsCreatorApproval) {
      return 'Your invite is waiting for the room creator to verify it. '
          'You will be able to accept it after that.';
    }
    if (preview.isPending) {
      return preview.requestKind == 'invite'
          ? 'Your invite is verified. Accept it in REQUESTS on your home '
                'screen.'
          : 'Your request is with the room creator. You get in only after '
                'they approve it.';
    }
    return preview.isOpenJoin
        ? 'This room accepts link requests. Ask to join and the creator will '
              'decide.'
        : 'This room asks people to request access. The creator will decide '
              'whether to let you in.';
  }
}
