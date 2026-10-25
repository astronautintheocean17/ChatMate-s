// lib/admin/screens/admin-room-details-screen.dart
import 'package:flutter/material.dart';

import '../../common/utils/format.dart';
import '../../data/admin-service.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../theme/app-theme.dart';

class AdminRoomDetailsScreen extends StatefulWidget {
  final String roomId;
  const AdminRoomDetailsScreen({super.key, required this.roomId});

  @override
  State<AdminRoomDetailsScreen> createState() =>
      _AdminRoomDetailsScreenState();
}

class _AdminRoomDetailsScreenState extends State<AdminRoomDetailsScreen> {
  late Future<AdminRoomSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _snapshot = AdminService.roomDetails(widget.roomId));
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bg(context);
    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accent(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FutureBuilder<AdminRoomSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        friendlyError(snapshot.error!),
                        textAlign: TextAlign.center,
                        style: AppText.body(13, color: muted),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            final room = data.room;
            final visibility = room['visibility'] as String? ?? 'private';
            final memberCount = (room['member_count'] as num?)?.toInt() ?? 0;
            final created = DateTime.tryParse(
              room['created_at'] as String? ?? '',
            );

            return DefaultTabController(
              length: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 20, 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Back',
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ADMIN / ROOM',
                          style: AppText.mono(11, color: accent, ls: 1.6),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room['name'] as String? ?? 'Untitled',
                          style: AppText.serif(32, color: ink, h: 1.0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${room['code']}  ·  $visibility  ·  '
                          'creator @${room['creator_handle']}  ·  '
                          '$memberCount members',
                          style: AppText.mono(9, color: muted, ls: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'created ${shortDate(created)}',
                          style: AppText.mono(9, color: muted, ls: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off_outlined,
                                size: 13,
                                color: accent,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'GHOST READ',
                                style: AppText.mono(8, color: accent, ls: 1.2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    labelColor: accent,
                    unselectedLabelColor: muted,
                    indicatorColor: accent,
                    labelStyle: AppText.mono(10, ls: 1.2),
                    tabs: const [
                      Tab(text: 'MEMBERS'),
                      Tab(text: 'REQUESTS'),
                      Tab(text: 'MESSAGES'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _MembersTab(members: data.members),
                        _RequestsTab(requests: data.requests),
                        _MessagesTab(messages: data.messages),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}


class _MembersTab extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  const _MembersTab({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const _Empty(text: 'No members.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final member = members[index];
        final role = member['role'] as String? ?? 'member';
        final joined = DateTime.tryParse(
          member['joined_at'] as String? ?? '',
        );
        return _RowCard(
          leading: '@${member['handle']}',
          meta: 'joined ${shortDate(joined)}',
          trailing: role == 'creator' ? 'CREATOR' : 'MEMBER',
          highlight: role == 'creator',
        );
      },
    );
  }
}

class _RequestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  const _RequestsTab({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _Empty(text: 'No requests yet.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final request = requests[index];
        final kind = request['kind'] as String? ?? 'join';
        final status = request['status'] as String? ?? 'pending';
        return _RowCard(
          leading: '@${request['handle']}',
          meta: kind == 'invite' ? 'invited by the creator' : 'asked to join',
          trailing: status.toUpperCase(),
          highlight: status == 'pending',
        );
      },
    );
  }
}


class _MessagesTab extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  const _MessagesTab({required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _Empty(text: 'No messages in this room.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _MessageCard(message: messages[index]),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final accent = AppTheme.accent(context);
    final deleted = message['deleted_at'] != null;
    final handle = message['sender_handle'] as String?;
    final revealed = message['reveal_sender'] == true;
    final body = message['body'] as String? ?? '';
    final readCount = (message['read_count'] as num?)?.toInt() ?? 0;
    final created = DateTime.tryParse(message['created_at'] as String? ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deleted
                      ? 'DELETED'
                      : handle != null
                          ? '@$handle'
                          : 'ANONYMOUS SENDER',
                  style: AppText.mono(
                    9,
                    color: handle != null ? ink : muted,
                    ls: 0.8,
                  ),
                ),
              ),
              if (revealed && !deleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(border: Border.all(color: accent)),
                  child: Text(
                    'REVEALED',
                    style: AppText.mono(7, color: accent, ls: 0.8),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                created == null ? '' : clockTime(created),
                style: AppText.mono(9, color: muted, ls: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            deleted ? 'Message deleted by its sender or the creator.' : body,
            style: AppText.body(
              13,
              color: deleted ? muted : ink,
              h: 1.45,
            ).copyWith(
              fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'read by $readCount',
            style: AppText.mono(9, color: muted, ls: 0.4),
          ),
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  final String leading;
  final String meta;
  final String trailing;
  final bool highlight;
  const _RowCard({
    required this.leading,
    required this.meta,
    required this.trailing,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leading,
                  style: AppText.body(13, color: AppTheme.ink(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: AppText.mono(
                    9,
                    color: AppTheme.muted(context),
                    ls: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: AppText.mono(
              8,
              color: highlight ? accent : AppTheme.muted(context),
              ls: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: AppText.body(13, color: AppTheme.muted(context)),
      ),
    );
  }
}

