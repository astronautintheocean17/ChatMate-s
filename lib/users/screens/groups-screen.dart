// lib/users/screens/groups-screen.dart
// Groups only: the rooms I have joined, without the direct chats.

import 'package:flutter/material.dart';

import '../../common/utils/format.dart';
import '../../common/widgets/mate-avatar.dart';
import '../../data/errors.dart';
import '../../data/social-models.dart';
import '../../data/social-service.dart';
import '../../theme/app-theme.dart';
import 'chat-room-screen.dart';
import 'create-room-screen.dart';
import 'join-room-screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<ConversationEntry> _groups = const [];
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
      final all = await SocialService.conversations();
      if (!mounted) return;
      setState(() => _groups = all.where((entry) => !entry.isDirect).toList());
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

  Future<void> _openChat(ConversationEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(roomId: entry.id, roomName: entry.title),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: Text(
          'Groups',
          style: AppText.serif(22, color: AppTheme.ink(context), ls: -0.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Join with a code',
            icon: const Icon(Icons.key_rounded, size: 19),
            onPressed: () => _open(const JoinRoomScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(const CreateRoomScreen()),
        backgroundColor: AppTheme.accent(context),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 22),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.accent(context),
        child: _body(),
      ),
    );
  }

  Widget _body() {
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

    if (_groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 90, 32, 20),
        children: [
          Icon(
            Icons.groups_outlined,
            size: 34,
            color: AppTheme.accent(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No groups yet.',
            textAlign: TextAlign.center,
            style: AppText.serif(24, color: AppTheme.ink(context)),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a room for your circle, or join one with a code.',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppTheme.muted(context), h: 1.6),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _groups.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final group = _groups[index];
        final identity = group.revealsEveryone
            ? 'Names visible'
            : group.isAnonymousRoom
            ? 'Anonymous'
            : 'Reveal per message';

        return InkWell(
          onTap: () => _openChat(group),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.line(context)),
            ),
            child: Row(
              children: [
                MateAvatar(handle: group.title, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          15,
                          color: AppTheme.ink(context),
                          w: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${group.memberCount} member'
                        '${group.memberCount == 1 ? '' : 's'} · $identity',
                        style: AppText.body(
                          11.5,
                          color: AppTheme.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      relativeTime(group.lastMessageAt),
                      style: AppText.body(
                        10,
                        color: AppTheme.muted(context),
                        w: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.code,
                      style: AppText.mono(
                        9.5,
                        color: AppTheme.accent(context),
                        ls: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
