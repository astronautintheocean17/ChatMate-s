// lib/users/screens/home-screen.dart
// The Home tab: a WhatsApp-style list of every conversation I am part of —
// direct chats, groups, and the chat requests waiting on me.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../common/screens/app-shell.dart';
import '../../common/utils/format.dart';
import '../../common/widgets/mate-avatar.dart';
import '../../common/widgets/theme-toggle-button.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/profile-service.dart';
import '../../data/room-service.dart';
import '../../data/social-models.dart';
import '../../data/social-service.dart';
import '../../theme/app-theme.dart';
import 'chat-room-screen.dart';
import 'create-room-screen.dart';
import 'groups-screen.dart';
import 'join-room-screen.dart';
import 'requests-screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  Profile? _profile;
  List<ConversationEntry> _conversations = const [];
  List<ChatRequestItem> _requests = const [];
  List<RoomRequestItem> _invites = const [];
  List<HomeSearchEntry> _results = const [];
  Timer? _debounce;
  String _query = '';
  bool _loading = true;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ProfileService.current();
      final conversations = await SocialService.conversations();
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
        _profile = profile;
        _conversations = conversations;
        _requests = requests.where((r) => r.isIncoming).toList();
        _invites = invites;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQuery(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 260), () => _search(value));
  }

  Future<void> _search(String value) async {
    setState(() => _searching = true);
    try {
      final results = await SocialService.homeSearch(value);
      if (!mounted || _query != value) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openChat(String roomId, String name) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(roomId: roomId, roomName: name),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  Future<void> _compose() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.line(sheetContext),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            _SheetAction(
              icon: Icons.person_add_alt_1_rounded,
              title: 'New chat',
              subtitle: 'Send a request to a ChatMate ID',
              onTap: () => Navigator.pop(sheetContext, 'chat'),
            ),
            _SheetAction(
              icon: Icons.group_add_rounded,
              title: 'New group',
              subtitle: 'Create a room for your circle',
              onTap: () => Navigator.pop(sheetContext, 'group'),
            ),
            _SheetAction(
              icon: Icons.key_rounded,
              title: 'Join with a code',
              subtitle: 'Enter a room name or code',
              onTap: () => Navigator.pop(sheetContext, 'join'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case 'chat':
        AppShell.open(context, AppTab.search);
      case 'group':
        await _push(const CreateRoomScreen());
      case 'join':
        await _push(const JoinRoomScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface(context),
      floatingActionButton: FloatingActionButton(
        onPressed: _compose,
        backgroundColor: AppTheme.accent(context),
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.edit_outlined, size: 21),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _searchField(),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.accent(context),
                onRefresh: _load,
                child: _query.trim().isEmpty
                    ? _buildConversations()
                    : _buildSearchResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final profile = _profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 6),
      child: Row(
        children: [
          Text(
            'ChatMate',
            style: AppText.serif(26, color: AppTheme.ink(context), ls: -1),
          ),
          const SizedBox(width: 8),
          if (profile != null)
            Flexible(
              child: Text(
                '@${profile.handle}',
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  11.5,
                  color: AppTheme.muted(context),
                  w: FontWeight.w500,
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Groups',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.groups_outlined, size: 20),
            onPressed: () => _push(const GroupsScreen()),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: () => AppShell.open(context, AppTab.profile),
            child: MateAvatar(handle: profile?.handle ?? '?', size: 36),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.bg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.line(context)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: AppTheme.muted(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onQuery,
                textInputAction: TextInputAction.search,
                style: AppText.body(13.5, color: AppTheme.ink(context)),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search chats and groups',
                  hintStyle: AppText.body(13.5, color: AppTheme.muted(context)),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              InkWell(
                onTap: () {
                  _searchController.clear();
                  _onQuery('');
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.muted(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversations() {
    if (_loading && _conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accent(context),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      children: [
        if (_error != null) _Banner(message: _error!, onRetry: _load),
        if (_requests.isNotEmpty || _invites.isNotEmpty)
          _RequestsBanner(
            count: _requests.length + _invites.length,
            onTap: () => _push(const RequestsScreen()),
          ),
        if (_conversations.isEmpty)
          _EmptyState(onCompose: _compose)
        else
          ..._conversations.map(
            (entry) => _ConversationTile(
              entry: entry,
              onTap: () => _openChat(entry.id, entry.title),
            ),
          ),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searching && _results.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_results.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.travel_explore_rounded,
            size: 28,
            color: AppTheme.muted(context),
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing here matches "$_query".',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppTheme.muted(context)),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => AppShell.open(context, AppTab.search),
              child: Text(
                'SEARCH ALL CHATMATE IDS',
                style: AppText.mono(10, color: AppTheme.accent(context)),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final entry = _results[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 2,
          ),
          leading: MateAvatar(
            handle: entry.handle ?? entry.title,
            size: 44,
            anonymous: entry.handle == null,
          ),
          title: Text(
            entry.isChat ? '@${entry.handle}' : entry.title,
            style: AppText.body(
              14.5,
              color: AppTheme.ink(context),
              w: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            entry.isChat
                ? 'Private chat'
                : 'Group · ${entry.memberCount} member'
                      '${entry.memberCount == 1 ? '' : 's'}',
            style: AppText.body(11.5, color: AppTheme.muted(context)),
          ),
          onTap: () => _openChat(entry.id, entry.title),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.entry, required this.onTap});

  final ConversationEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = entry.unreadCount > 0;
    final preview = (entry.lastPreview ?? '').trim();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            MateAvatar(
              handle: entry.isDirect
                  ? (entry.otherHandle ?? entry.title)
                  : entry.title,
              size: 50,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!entry.isDirect)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Icon(
                            Icons.groups_rounded,
                            size: 13,
                            color: AppTheme.muted(context),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          entry.isDirect
                              ? '@${entry.otherHandle ?? entry.title}'
                              : entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            15,
                            color: AppTheme.ink(context),
                            w: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        relativeTime(entry.lastMessageAt),
                        style: AppText.body(
                          10.5,
                          color: unread
                              ? AppTheme.accent(context)
                              : AppTheme.muted(context),
                          w: unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview.isEmpty
                              ? (entry.isDirect
                                    ? 'Say something. It starts here.'
                                    : _roomSubtitle(entry))
                              : preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            12.5,
                            color: AppTheme.muted(context),
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent(context),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '${entry.unreadCount}',
                            style: AppText.body(
                              10,
                              color: Colors.white,
                              w: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roomSubtitle(ConversationEntry entry) {
    final members =
        '${entry.memberCount} member'
        '${entry.memberCount == 1 ? '' : 's'}';
    final identity = entry.revealsEveryone
        ? 'names visible'
        : entry.isAnonymousRoom
        ? 'anonymous'
        : 'reveal per message';
    return '$members · $identity';
  }
}

class _RequestsBanner extends StatelessWidget {
  const _RequestsBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.mark_chat_unread_outlined, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count == 1
                      ? '1 request is waiting'
                      : '$count requests are waiting',
                  style: AppText.body(
                    13,
                    color: AppTheme.ink(context),
                    w: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCompose});

  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 70, 32, 20),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 34, color: AppTheme.accent(context)),
          const SizedBox(height: 16),
          Text(
            'No chats yet.',
            textAlign: TextAlign.center,
            style: AppText.serif(26, color: AppTheme.ink(context), h: 1.1),
          ),
          const SizedBox(height: 8),
          Text(
            'Find a ChatMate ID and send a request, or open a room of your '
            'own. Nothing shows your name until you say so.',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppTheme.muted(context), h: 1.6),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCompose,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('START A CHAT'),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.accent(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 19, color: AppTheme.accent(context)),
      ),
      title: Text(
        title,
        style: AppText.body(
          14.5,
          color: AppTheme.ink(context),
          w: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppText.body(11.5, color: AppTheme.muted(context)),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
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
