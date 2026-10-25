// lib/users/screens/home-screen.dart
import 'package:flutter/material.dart';

import '../../common/utils/format.dart';
import '../../common/widgets/theme-toggle-button.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/profile-service.dart';
import '../../data/room-service.dart';
import '../../theme/app-theme.dart';
import 'chat-room-screen.dart';
import 'create-room-screen.dart';
import 'existing-rooms-screen.dart';
import 'join-room-screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Profile? _profile;
  List<RoomSummary> _rooms = const [];
  int _invites = 0;
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
      final profile = await ProfileService.current();
      final rooms = await RoomService.myRooms();
      final requests = await RoomService.myRequests();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _rooms = rooms;
        _invites = requests.where((r) => r.isInvite && r.isPending).length;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  Future<void> _openChat(RoomSummary room) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(roomId: room.id, roomName: room.name),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openRequests() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _RequestsSheet(),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _editHandle() async {
    final profile = _profile;
    if (profile == null) return;

    final controller = TextEditingController(text: profile.handle);
    final formKey = GlobalKey<FormState>();
    String? error;
    var busy = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface(dialogContext),
          shape: const RoundedRectangleBorder(),
          title: Text(
            'Change your ID',
            style: AppText.serif(26, color: AppTheme.ink(dialogContext)),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your old handle stops working immediately. Messages already '
                  'sent stay anonymous.',
                  style: AppText.body(
                    12.5,
                    color: AppTheme.muted(dialogContext),
                    h: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  enabled: !busy,
                  validator: (value) {
                    final handle = ProfileService.normalizeHandle(value ?? '');
                    if (!ProfileService.isValidHandle(handle)) {
                      return 'Use 3-24 lowercase letters, numbers or _.';
                    }
                    if (handle == profile.handle) {
                      return 'That is already your ID.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'New ChatMate ID',
                    prefixText: '@',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: AppText.body(
                      12,
                      color: AppTheme.accent(dialogContext),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      final handle = ProfileService.normalizeHandle(
                        controller.text,
                      );
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        if (!await ProfileService.handleAvailable(handle)) {
                          setDialogState(() {
                            busy = false;
                            error = 'That ID is already taken.';
                          });
                          return;
                        }
                        await ProfileService.changeHandle(handle);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (err) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          busy = false;
                          error = friendlyError(err);
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SAVE'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ChatMate ID updated.')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: AppTheme.surface(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.accent(context),
          backgroundColor: AppTheme.surface(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              _header(context, profile),
              const SizedBox(height: 30),
              if (_error != null) ...[
                _ErrorBanner(message: _error!, onRetry: _load),
                const SizedBox(height: 20),
              ],
              Text.rich(
                TextSpan(
                  style: AppText.serif(
                    42,
                    color: AppTheme.ink(context),
                    h: 0.98,
                  ),
                  children: [
                    const TextSpan(text: 'Every room\nhas a '),
                    TextSpan(
                      text: 'secret.',
                      style: AppText.serif(
                        42,
                        color: AppTheme.accent(context),
                        w: FontWeight.w400,
                        style: FontStyle.italic,
                        h: 0.98,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Open a room you already belong to, start a new one for your '
                'circle, or join with a search. Inside, nothing you say carries '
                'your name.',
                style: AppText.body(
                  13.5,
                  color: AppTheme.muted(context),
                  h: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      label: 'CREATE',
                      title: 'New room',
                      caption: 'Start a private space',
                      icon: Icons.add_rounded,
                      filled: true,
                      onTap: () => _open(const CreateRoomScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      label: 'JOIN',
                      title: 'Enter',
                      caption: 'Use a name or code',
                      icon: Icons.subdirectory_arrow_right_rounded,
                      onTap: () => _open(const JoinRoomScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ActionCard(
                label: 'LIBRARY',
                title: 'All your rooms',
                caption: '${_rooms.length} joined · open and manage',
                icon: Icons.grid_view_rounded,
                onTap: () => _open(const ExistingRoomsScreen()),
              ),
              const SizedBox(height: 34),
              Row(
                children: [
                  Text(
                    'YOUR ROOMS',
                    style: AppText.mono(
                      11,
                      color: AppTheme.muted(context),
                      ls: 1.6,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_rooms.length}',
                    style: AppText.mono(11, color: AppTheme.accent(context)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading && _rooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_rooms.isEmpty)
                _EmptyRooms(
                  onCreate: () => _open(const CreateRoomScreen()),
                  onJoin: () => _open(const JoinRoomScreen()),
                )
              else
                ..._rooms.map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RoomTile(room: room, onTap: () => _openChat(room)),
                  ),
                ),
              const SizedBox(height: 30),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Profile? profile) {
    final initials = (profile?.handle.isNotEmpty ?? false)
        ? profile!.handle.characters.first.toUpperCase()
        : '·';
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: profile == null ? null : _editHandle,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.ink(context),
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: AppText.serif(20, color: AppTheme.surface(context)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: profile == null ? null : _editHandle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile == null ? 'LOADING' : 'SIGNED IN ANONYMOUSLY',
                  style: AppText.mono(
                    9.5,
                    color: AppTheme.muted(context),
                    ls: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile == null ? '—' : '@${profile.handle}',
                        overflow: TextOverflow.ellipsis,
                        style: AppText.mono(13, color: AppTheme.ink(context)),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: AppTheme.muted(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _RequestsButton(count: _invites, onTap: _openRequests),
        const SizedBox(width: 8),
        const ThemeToggleButton(),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    return Text(
      'NO SENDER. NO TRACE.',
      style: AppText.mono(9, color: AppTheme.muted(context), ls: 1.2),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.label,
    required this.title,
    required this.caption,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final String title;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppTheme.accent(context) : AppTheme.surface(context);
    final fg = filled ? Colors.white : AppTheme.ink(context);
    final sub = filled ? Colors.white70 : AppTheme.muted(context);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled
                  ? AppTheme.accent(context)
                  : AppTheme.border(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: AppText.mono(8.5, color: sub, ls: 1.3)),
                  const Spacer(),
                  Icon(icon, size: 18, color: fg),
                ],
              ),
              const SizedBox(height: 14),
              Text(title, style: AppText.serif(20, color: fg, h: 1.05)),
              const SizedBox(height: 4),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(10.5, color: sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsButton extends StatelessWidget {
  const _RequestsButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.mail_outline_rounded,
                size: 17,
                color: AppTheme.ink(context),
              ),
              if (count > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.accent(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onTap});

  final RoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  room.isPrivate
                      ? Icons.lock_outline_rounded
                      : Icons.public_rounded,
                  size: 16,
                  color: AppTheme.muted(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.serif(18, color: AppTheme.ink(context)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${room.accessMode == 'request'
                          ? 'PRIVATE · REQUEST ONLY'
                          : room.accessMode == 'link'
                          ? 'PUBLIC · OPEN LINK'
                          : 'PUBLIC · OPEN TO ALL'} · '
                      '${room.memberCount} MEMBERS'
                      '${room.isCreator ? ' · CREATOR' : ''}',
                      style: AppText.mono(
                        8.5,
                        color: AppTheme.muted(context),
                        ls: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (room.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent(context),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${room.unreadCount}',
                        style: AppText.mono(9, color: Colors.white),
                      ),
                    )
                  else if (room.lastMessageAt != null)
                    Text(
                      relativeTime(room.lastMessageAt),
                      style: AppText.mono(9, color: AppTheme.muted(context)),
                    ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppTheme.muted(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.accent(context).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppText.body(12, color: AppTheme.ink(context)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No rooms yet.',
            style: AppText.serif(22, color: AppTheme.ink(context)),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a room and invite someone, or enter a code you were given.',
            style: AppText.body(12.5, color: AppTheme.muted(context), h: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: onCreate,
                child: const Text('CREATE A ROOM'),
              ),
              const SizedBox(width: 6),
              TextButton(onPressed: onJoin, child: const Text('JOIN ONE')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestsSheet extends StatefulWidget {
  const _RequestsSheet();

  @override
  State<_RequestsSheet> createState() => _RequestsSheetState();
}

class _RequestsSheetState extends State<_RequestsSheet> {
  List<RoomRequestItem> _items = const [];
  final Set<String> _busy = {};
  bool _loading = true;
  bool _changed = false;
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
      final items = await RoomService.myRequests();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(RoomRequestItem item, bool accept) async {
    if (accept && item.needsCreatorApproval) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The room creator still needs to verify this invite.'),
        ),
      );
      return;
    }
    setState(() => _busy.add(item.requestId));
    try {
      await RoomService.respondRequest(
        requestId: item.requestId,
        accept: accept,
      );
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'You joined ${item.roomName}.' : 'Invitation declined.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy.remove(item.requestId));
    }
  }

  Future<void> _openRoom(RoomRequestItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatRoomScreen(roomId: item.roomId, roomName: item.roomName),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final invites = _items.where((r) => r.isInvite && r.isPending).toList();
    final outgoing = _items.where((r) => !r.isInvite && r.isPending).toList();
    final history = _items.where((r) => !r.isPending).toList();

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
              child: Row(
                children: [
                  Text(
                    'REQUESTS',
                    style: AppText.mono(
                      10,
                      color: AppTheme.muted(context),
                      ls: 1.6,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _changed),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                      children: [
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: AppText.body(
                              12,
                              color: AppTheme.accent(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (invites.isEmpty && outgoing.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              'Nothing waiting. Invitations and join requests '
                              'will appear here.',
                              style: AppText.body(
                                13,
                                color: AppTheme.muted(context),
                                h: 1.5,
                              ),
                            ),
                          ),
                        ...invites.map(
                          (item) => _RequestCard(
                            item: item,
                            busy: _busy.contains(item.requestId),
                            onAccept: () => _respond(item, true),
                            onDecline: () => _respond(item, false),
                          ),
                        ),
                        ...outgoing.map((item) => _RequestCard(item: item)),
                        if (history.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'HISTORY',
                            style: AppText.mono(
                              9,
                              color: AppTheme.muted(context),
                              ls: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...history.map(
                            (item) => _RequestCard(
                              item: item,
                              onOpen: item.isAccepted
                                  ? () => _openRoom(item)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    this.busy = false,
    this.onAccept,
    this.onDecline,
    this.onOpen,
  });

  final RoomRequestItem item;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.isInvite
        ? item.needsCreatorApproval
              ? '@${item.otherHandle} invited you · creator verifying'
              : '@${item.otherHandle} invited you'
        : 'You asked to join';
    final statusLabel = item.needsCreatorApproval
        ? 'AWAITING CREATOR'
        : item.status.toUpperCase();
    final created = relativeTime(item.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.roomName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.serif(19, color: AppTheme.ink(context)),
                ),
              ),
              Text(
                statusLabel,
                style: AppText.mono(
                  8,
                  color: item.isPending
                      ? AppTheme.accent(context)
                      : AppTheme.muted(context),
                  ls: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '$subtitle · ${item.visibility}${created.isEmpty ? '' : ' · $created'}',
            style: AppText.body(11.5, color: AppTheme.muted(context)),
          ),
          if (item.isPending && item.isInvite) ...[
            if (item.needsCreatorApproval) ...[
              const SizedBox(height: 10),
              Text(
                'The room creator must verify this invite before you can '
                'accept it.',
                style: AppText.body(
                  11.5,
                  color: AppTheme.muted(context),
                  h: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!item.needsCreatorApproval) ...[
                  Expanded(
                    child: _SheetButton(
                      label: 'ACCEPT',
                      filled: true,
                      busy: busy,
                      onTap: onAccept,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _SheetButton(
                    label: 'DECLINE',
                    busy: busy,
                    onTap: onDecline,
                  ),
                ),
              ],
            ),
          ] else if (onOpen != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpen,
                child: const Text('OPEN ROOM'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppTheme.ink(context) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: filled ? AppTheme.ink(context) : AppTheme.border(context),
            ),
          ),
          child: busy
              ? SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: filled ? Colors.white : AppTheme.ink(context),
                  ),
                )
              : Text(
                  label,
                  style: AppText.mono(
                    10,
                    color: filled
                        ? AppTheme.surface(context)
                        : AppTheme.ink(context),
                    ls: 1.2,
                  ),
                ),
        ),
      ),
    );
  }
}
