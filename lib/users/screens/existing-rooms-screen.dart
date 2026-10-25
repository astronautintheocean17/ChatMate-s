// lib/users/screens/existing-rooms-screen.dart
import 'package:flutter/material.dart';
import '../../common/utils/format.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/room-service.dart';
import '../../theme/app-theme.dart';
import 'chat-room-screen.dart';
import 'join-room-screen.dart';

class ExistingRoomsScreen extends StatefulWidget {
  const ExistingRoomsScreen({super.key});

  @override
  State<ExistingRoomsScreen> createState() => _ExistingRoomsScreenState();
}

class _ExistingRoomsScreenState extends State<ExistingRoomsScreen> {
  List<RoomSummary> _rooms = const [];
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
      final rooms = await RoomService.myRooms();
      if (!mounted) return;
      setState(() => _rooms = rooms);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(RoomSummary room) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId: room.id,
          roomName: room.name,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final created = _rooms.where((room) => room.isCreator).toList();
    final joined = _rooms.where((room) => !room.isCreator).toList();
    final unread = _rooms.fold<int>(0, (sum, room) => sum + room.unreadCount);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: Text(
          'YOUR ROOMS',
          style: AppText.mono(
            10,
            color: AppTheme.muted(context),
            ls: 1.8,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 19),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.accent(context),
          backgroundColor: AppTheme.surface(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(
                'Every room\nkept here.',
                style: AppText.serif(
                  36,
                  color: AppTheme.ink(context),
                  h: 0.98,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_rooms.length} rooms · $unread unread',
                style: AppText.mono(
                  9.5,
                  color: AppTheme.muted(context),
                  ls: 1.1,
                ),
              ),
              const SizedBox(height: 26),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: AppText.body(
                    12,
                    color: AppTheme.accent(context),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_loading && _rooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_rooms.isEmpty)
                _EmptyLibrary(
                  onJoin: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const JoinRoomScreen(),
                      ),
                    );
                    if (mounted) _load();
                  },
                )
              else ...[
                if (created.isNotEmpty) ...[
                  const _LibraryLabel('ROOMS YOU CREATED'),
                  const SizedBox(height: 9),
                  ...created.map(
                    (room) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _LibraryTile(
                        room: room,
                        onTap: () => _open(room),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (joined.isNotEmpty) ...[
                  const _LibraryLabel('ROOMS YOU JOINED'),
                  const SizedBox(height: 9),
                  ...joined.map(
                    (room) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _LibraryTile(
                        room: room,
                        onTap: () => _open(room),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _LibraryLabel extends StatelessWidget {
  const _LibraryLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.mono(
        9,
        color: AppTheme.muted(context),
        ls: 1.4,
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.room, required this.onTap});

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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.serif(
                              19,
                              color: AppTheme.ink(context),
                            ),
                          ),
                        ),
                        if (room.unreadCount > 0) ...[
                          const SizedBox(width: 8),
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
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${room.isPrivate ? 'PRIVATE' : 'PUBLIC'} · '
                      '${room.memberCount} MEMBERS'
                      '${room.lastMessageAt == null ? '' : ' · ${relativeTime(room.lastMessageAt)}'}',
                      style: AppText.mono(
                        8.5,
                        color: AppTheme.muted(context),
                        ls: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    room.code,
                    style: AppText.mono(
                      9.5,
                      color: AppTheme.ink(context),
                      ls: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
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

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onJoin});

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
            'A quiet shelf.',
            style: AppText.serif(21, color: AppTheme.ink(context)),
          ),
          const SizedBox(height: 6),
          Text(
            'Rooms you create or are accepted into will be listed here.',
            style: AppText.body(
              12.5,
              color: AppTheme.muted(context),
              h: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onJoin,
            child: const Text('FIND A ROOM'),
          ),
        ],
      ),
    );
  }
}

