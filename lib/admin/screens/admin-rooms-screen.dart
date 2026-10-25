// lib/admin/screens/admin-rooms-screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../common/utils/format.dart';
import '../../data/admin-service.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../theme/app-theme.dart';
import 'admin-room-details-screen.dart';

class AdminRoomsScreen extends StatefulWidget {
  const AdminRoomsScreen({super.key});

  @override
  State<AdminRoomsScreen> createState() => _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends State<AdminRoomsScreen> {
  late Future<List<AdminRoom>> _rooms;
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    setState(() => _rooms = AdminService.rooms(query: _query));
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value);
      _load();
    });
  }

  void _open(AdminRoom room) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => AdminRoomDetailsScreen(roomId: room.id),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accent(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 48 : 20,
              vertical: 24,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ADMIN / ROOMS',
                    style: AppText.mono(11, color: accent, ls: 1.6),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Every room.',
                style: AppText.serif(wide ? 42 : 34, color: ink),
              ),
              const SizedBox(height: 8),
              Text(
                'Search by name or the exact 6-character code. Public and '
                'private rooms are both visible here.',
                style: AppText.body(13, color: muted, h: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                onChanged: _onSearch,
                style: AppText.body(14, color: ink),
                decoration: InputDecoration(
                  hintText: 'Room name or code',
                  hintStyle: AppText.body(14, color: muted),
                  prefixIcon: Icon(Icons.search, size: 18, color: muted),
                  filled: true,
                  fillColor: AppTheme.surface(context),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<AdminRoom>>(
                future: _rooms,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              friendlyError(snapshot.error!),
                              style: AppText.body(13, color: muted),
                            ),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: const Text('RETRY'),
                          ),
                        ],
                      ),
                    );
                  }
                  final rooms = snapshot.data ?? const <AdminRoom>[];
                  if (rooms.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No rooms match that search.',
                        style: AppText.body(13, color: muted),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final room in rooms) ...[
                        _RoomTile(room: room, onTap: () => _open(room)),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final AdminRoom room;
  final VoidCallback onTap;
  const _RoomTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accent(context);

    return Material(
      color: AppTheme.surface(context),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: line)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: accent),
                ),
                child: Text(
                  room.isPrivate ? 'PRIVATE' : 'PUBLIC',
                  style: AppText.mono(8, color: accent, ls: 1.0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: AppText.body(14, color: ink)),
                    const SizedBox(height: 3),
                    Text(
                      '${room.code}  ·  creator @${room.creatorHandle}  ·  '
                      '${shortDate(room.createdAt)}',
                      style: AppText.mono(9, color: muted, ls: 0.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${room.memberCount} members',
                    style: AppText.body(10, color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${room.messageCount} messages',
                    style: AppText.body(10, color: muted),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

