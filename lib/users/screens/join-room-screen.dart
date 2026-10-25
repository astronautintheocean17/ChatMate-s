// lib/users/screens/join-room-screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/room-service.dart';
import '../../theme/app-theme.dart';
import 'chat-room-screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _controller = TextEditingController();
  final Set<String> _busy = {};
  final Map<String, String?> _statusOverride = {};
  Timer? _debounce;
  List<RoomSearchResult> _results = const [];
  bool _loading = true;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 320),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim().toUpperCase();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await RoomService.searchRooms(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searched = query.isNotEmpty;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(RoomSearchResult room) async {
    if (room.isMember) {
      _openChat(room);
      return;
    }
    setState(() => _busy.add(room.id));
    try {
      final response = await RoomService.requestJoin(room.id);
      final status = response['status'] as String? ?? 'pending';
      if (!mounted) return;
      setState(() => _statusOverride[room.id] = status);
      if (status == 'member') {
        _openChat(room);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              room.isPrivate
                  ? 'Request sent to @${room.creatorHandle}.'
                  : 'Join request sent. The creator must approve it.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(room.id));
    }
  }

  Future<void> _openChat(RoomSearchResult room) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId: room.id,
          roomName: room.name,
        ),
      ),
    );
    if (mounted) _runSearch(_controller.text);
  }


  @override
  Widget build(BuildContext context) {
    final codeLike = RegExp(r'^[A-Z0-9]{6}$')
        .hasMatch(_controller.text.trim().toUpperCase());
    return Scaffold(
      backgroundColor: AppTheme.surface(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: Text(
          'JOIN A ROOM',
          style: AppText.mono(
            10,
            color: AppTheme.muted(context),
            ls: 1.8,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'Find your\npeople.',
              style: AppText.serif(
                38,
                color: AppTheme.ink(context),
                h: 0.98,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Search public rooms by name, or paste the six-character code '
              'for a private one.',
              style: AppText.body(
                13,
                color: AppTheme.muted(context),
                h: 1.55,
              ),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: (value) => _runSearch(value),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Room name or code',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        ),
                      )
                    : (_controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _controller.clear();
                              _runSearch('');
                            },
                            icon: const Icon(Icons.close_rounded, size: 17),
                          )),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              codeLike
                  ? 'CODE FORMAT · PRIVATE ROOMS INCLUDED'
                  : 'PUBLIC ROOMS · OR ENTER A FULL CODE',
              style: AppText.mono(
                8.5,
                color: AppTheme.muted(context),
                ls: 1.2,
              ),
            ),
            const SizedBox(height: 22),
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
            if (_loading && _results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_results.isEmpty)
              _EmptyResults(query: _controller.text.trim())
            else ...[
              Text(
                _searched ? 'MATCHES' : 'OPEN ROOMS',
                style: AppText.mono(
                  9.5,
                  color: AppTheme.muted(context),
                  ls: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              ..._results.map(
                (room) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoomResultTile(
                    room: room,
                    statusOverride: _statusOverride[room.id],
                    busy: _busy.contains(room.id),
                    onTap: () => _request(room),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _RoomResultTile extends StatelessWidget {
  const _RoomResultTile({
    required this.room,
    required this.statusOverride,
    required this.busy,
    required this.onTap,
  });

  final RoomSearchResult room;
  final String? statusOverride;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = statusOverride ?? room.requestStatus;
    final pending = status == 'pending' && !room.isMember;
    final canTap = !pending && !busy;

    final label = room.isMember
        ? 'OPEN'
        : pending
            ? 'REQUESTED'
            : 'REQUEST';

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: canTap ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    room.isPrivate
                        ? Icons.lock_outline_rounded
                        : Icons.public_rounded,
                    size: 15,
                    color: AppTheme.muted(context),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.serif(
                        20,
                        color: AppTheme.ink(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    room.code,
                    style: AppText.mono(
                      9.5,
                      color: AppTheme.muted(context),
                      ls: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${room.memberCount} MEMBERS · BY @${room.creatorHandle}',
                style: AppText.mono(
                  8.5,
                  color: AppTheme.muted(context),
                  ls: 0.8,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'The creator approves every entry.',
                      style: AppText.body(
                        11,
                        color: AppTheme.muted(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: room.isMember || !pending
                          ? AppTheme.ink(context)
                          : AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: room.isMember || !pending
                            ? AppTheme.ink(context)
                            : AppTheme.border(context),
                      ),
                    ),
                    child: busy
                        ? SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: room.isMember || !pending
                                  ? AppTheme.surface(context)
                                  : AppTheme.ink(context),
                            ),
                          )
                        : Text(
                            label,
                            style: AppText.mono(
                              8.5,
                              color: room.isMember || !pending
                                  ? AppTheme.surface(context)
                                  : AppTheme.muted(context),
                              ls: 1,
                            ),
                          ),
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


class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});

  final String query;

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
            query.isEmpty ? 'No public rooms yet.' : 'No room matches.',
            style: AppText.serif(21, color: AppTheme.ink(context)),
          ),
          const SizedBox(height: 6),
          Text(
            query.isEmpty
                ? 'Private rooms never show up here. Ask for their code, or '
                    'create the first public room.'
                : 'Check the spelling, or paste the exact six-character code '
                    'if you were invited to a private room.',
            style: AppText.body(
              12.5,
              color: AppTheme.muted(context),
              h: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

