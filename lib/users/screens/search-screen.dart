// lib/users/screens/search-screen.dart
// The Search tab: keyword search over ChatMate IDs. Nothing is listed until
// you type — the directory is never browsable.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../common/widgets/mate-avatar.dart';
import '../../data/errors.dart';
import '../../data/social-models.dart';
import '../../data/social-service.dart';
import '../../theme/app-theme.dart';
import 'chat-room-screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final Set<String> _busy = <String>{};
  List<ProfileSearchResult> _results = const [];
  Timer? _debounce;
  bool _loading = false;
  bool _touched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Deliberately no initial fetch: an empty query must never list anyone.
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _touched = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _search(value);
    });
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
        _touched = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _touched = true;
    });
    try {
      final results = await SocialService.searchProfiles(query);
      if (!mounted) return;
      // A slower response for an older keystroke must not overwrite fresh
      // results, and must never show people for a now-empty box.
      if (_controller.text.trim() != query) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat(ProfileSearchResult entry) async {
    final roomId = entry.roomId;
    if (roomId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatRoomScreen(roomId: roomId, roomName: '@${entry.handle}'),
      ),
    );
    if (mounted) _search(_controller.text);
  }

  /// Tapping a person opens the chat straight away — no request, no note.
  Future<void> _startChat(ProfileSearchResult entry) async {
    setState(() => _busy.add(entry.handle));
    try {
      final result = await SocialService.startChat(entry.handle);
      if (!mounted) return;
      final roomId = result['room_id'] as String?;
      if (roomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open a chat with @${entry.handle}.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatRoomScreen(roomId: roomId, roomName: '@${entry.handle}'),
        ),
      );
      if (mounted) _search(_controller.text);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy.remove(entry.handle));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text(
                    'Search',
                    style: AppText.serif(
                      24,
                      color: AppTheme.ink(context),
                      ls: -0.8,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
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
                        controller: _controller,
                        onChanged: _onChanged,
                        textInputAction: TextInputAction.search,
                        style: AppText.body(14, color: AppTheme.ink(context)),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Find a ChatMate ID',
                          hintStyle: AppText.body(
                            14,
                            color: AppTheme.muted(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _results.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.accent(context),
        ),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: AppText.body(13, color: AppTheme.muted(context)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _search(_controller.text),
            child: const Text('TRY AGAIN'),
          ),
        ],
      );
    }

    if (_results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(32, 70, 32, 20),
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 32,
            color: AppTheme.accent(context),
          ),
          const SizedBox(height: 14),
          Text(
            _touched && _controller.text.trim().isNotEmpty
                ? 'No ChatMate ID matches that.'
                : 'Find someone by their ChatMate ID.',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppTheme.muted(context), h: 1.6),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _results.length,
      itemBuilder: (context, index) => _resultTile(_results[index]),
    );
  }

  Widget _resultTile(ProfileSearchResult entry) {
    final busy = _busy.contains(entry.handle);

    Widget action;
    if (busy) {
      action = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.6),
      );
    } else if (entry.alreadyChatting) {
      action = TextButton(
        onPressed: () => _openChat(entry),
        child: Text(
          'OPEN',
          style: AppText.mono(9.5, color: AppTheme.accent(context)),
        ),
      );
    } else {
      action = TextButton(
        onPressed: () => _startChat(entry),
        child: Text(
          'CHAT',
          style: AppText.mono(9.5, color: AppTheme.accent(context)),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      onTap: () => entry.alreadyChatting ? _openChat(entry) : _startChat(entry),
      leading: MateAvatar(handle: entry.handle, size: 44),
      title: Text(
        '@${entry.handle}',
        style: AppText.body(
          14.5,
          color: AppTheme.ink(context),
          w: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        entry.alreadyChatting
            ? 'In your chats'
            : (entry.displayName.trim().isEmpty
                  ? 'Tap to open the chat'
                  : entry.displayName.trim()),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.body(11.5, color: AppTheme.muted(context)),
      ),
      trailing: action,
    );
  }
}
