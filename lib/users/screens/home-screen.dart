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
import 'existing-rooms-screen.dart';
import 'join-room-screen.dart';
import 'requests-screen.dart';

/// The inbox switch: everything I am part of, groups only, or chats only.
enum _InboxFilter { all, groups, chats }

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
  _InboxFilter _filter = _InboxFilter.all;
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

  /// Home search only ever looks inside my own chats and rooms — anyone at all
  /// is found in the Search tab.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface(context),
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
          _inboxButton(),
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
                  hintText: 'Search your chats and rooms',
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

  Widget _inboxButton() {
    final count = _requests.length + _invites.length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _push(const RequestsScreen()),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.bg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line(context)),
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 22,
              color: AppTheme.ink(context),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: AppTheme.accent(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.surface(context),
                  width: 1.5,
                ),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: AppText.mono(9.5, color: Colors.white, ls: 0.2),
              ),
            ),
          ),
      ],
    );
  }

  /// The opening copy from the very first ChatMate home screen.
  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Every room\nhas a '),
                TextSpan(
                  text: 'secret.',
                  style: AppText.classic(
                    34,
                    color: AppTheme.accent(context),
                    style: FontStyle.italic,
                    h: 1.0,
                  ),
                ),
              ],
            ),
            style: AppText.classic(
              34,
              color: AppTheme.ink(context),
              w: FontWeight.w700,
              h: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Open a room you already belong to, start a new one for your '
            'circle, or join with a search. Inside, nothing you say carries '
            'your name.',
            style: AppText.classic(
              12.5,
              color: AppTheme.muted(context),
              h: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// New room / Enter / All your rooms — the first commit's three cards.
  Widget _actionCards(int joined) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ActionCard(
                    label: 'CREATE',
                    title: 'New room',
                    caption: 'Start a private space',
                    icon: Icons.add_rounded,
                    filled: true,
                    onTap: () => _push(const CreateRoomScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    label: 'JOIN',
                    title: 'Enter',
                    caption: 'Use a name or code',
                    icon: Icons.subdirectory_arrow_right_rounded,
                    filled: true,
                    onTap: () => _push(const JoinRoomScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            label: 'LIBRARY',
            title: 'All your rooms',
            caption: '$joined joined · open and manage',
            icon: Icons.grid_view_rounded,
            onTap: () => _push(const ExistingRoomsScreen()),
          ),
        ],
      ),
    );
  }

  /// All / Groups / Chats: which slice of the recents is on screen.
  Widget _inboxSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.bg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line(context)),
        ),
        child: Row(
          children: [
            _switchHalf(label: 'ALL', value: _InboxFilter.all),
            Container(width: 1, height: 20, color: AppTheme.line(context)),
            _switchHalf(label: 'GROUPS', value: _InboxFilter.groups),
            Container(width: 1, height: 20, color: AppTheme.line(context)),
            _switchHalf(label: 'CHATS', value: _InboxFilter.chats),
          ],
        ),
      ),
    );
  }

  Widget _switchHalf({required String label, required _InboxFilter value}) {
    final selected = _filter == value;
    final accent = AppTheme.accent(context);
    final color = selected ? accent : AppTheme.muted(context);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          if (_filter == value) return;
          setState(() => _filter = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(
              10.5,
              color: color,
              ls: 1.1,
              w: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// The count line above the recents, named after the active filter.
  Widget _sectionHeader(int count) {
    final label = switch (_filter) {
      _InboxFilter.all => 'ALL RECENTS',
      _InboxFilter.groups => 'GROUPS',
      _InboxFilter.chats => 'CHATS',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          Text(
            label,
            style: AppText.mono(11, color: AppTheme.muted(context), ls: 1.6),
          ),
          const Spacer(),
          Text(
            '$count',
            style: AppText.mono(11, color: AppTheme.accent(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildConversations() {
    final groups = _conversations.where((entry) => !entry.isDirect).toList();
    final chats = _conversations.where((entry) => entry.isDirect).toList();
    final visible = switch (_filter) {
      _InboxFilter.groups => groups,
      _InboxFilter.chats => chats,
      _InboxFilter.all => [..._conversations]..sort(_newestFirst),
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_error != null) _Banner(message: _error!, onRetry: _load),
        _hero(),
        _actionCards(groups.length),
        const SizedBox(height: 26),
        _inboxSwitch(),
        if (_invites.isNotEmpty && _filter != _InboxFilter.chats) ...[
          const SizedBox(height: 10),
          _RequestsBanner(
            count: _invites.length,
            onTap: () => _push(const RequestsScreen()),
          ),
        ],
        const SizedBox(height: 20),
        _sectionHeader(visible.length),
        if (_loading && _conversations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (visible.isEmpty)
          _emptyForFilter()
        else
          ...visible.map(
            (entry) => _ConversationTile(
              entry: entry,
              onTap: () => _openChat(entry.id, entry.title),
            ),
          ),
      ],
    );
  }

  int _newestFirst(ConversationEntry a, ConversationEntry b) {
    final left = a.lastMessageAt;
    final right = b.lastMessageAt;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }

  Widget _emptyForFilter() {
    if (_filter == _InboxFilter.chats) {
      return _EmptyState(onSearch: () => AppShell.open(context, AppTab.search));
    }
    final copy = _filter == _InboxFilter.groups
        ? 'No groups yet.\nUse New room above, or enter a code.'
        : 'Nothing here yet.\nCreate a room, or find someone in Search.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
      child: Text(
        copy,
        textAlign: TextAlign.center,
        style: AppText.body(13, color: AppTheme.muted(context), h: 1.6),
      ),
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

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _searchLabel('YOUR CHATS & ROOMS'),
        ..._results.map(
          (entry) => ListTile(
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
          ),
        ),
      ],
    );
  }

  Widget _searchLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Text(
        label,
        style: AppText.mono(10, color: AppTheme.muted(context), ls: 1.2),
      ),
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
  const _EmptyState({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 44, 32, 20),
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
            'Find a ChatMate ID in Search and the chat opens right away — no '
            'requests. Rooms keep their own anonymity.',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppTheme.muted(context), h: 1.6),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('FIND SOMEONE'),
          ),
        ],
      ),
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
