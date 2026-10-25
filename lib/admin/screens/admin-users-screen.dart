// lib/admin/screens/admin-users-screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../common/utils/format.dart';
import '../../data/admin-service.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../theme/app-theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<AdminUser>> _users;
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
    setState(() => _users = AdminService.users(query: _query));
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value);
      _load();
    });
  }

  void _inspect(AdminUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _UserSheet(user: user),
    );
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
                    'ADMIN / USERS',
                    style: AppText.mono(11, color: accent, ls: 1.6),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Every handle.',
                style: AppText.serif(wide ? 42 : 34, color: ink),
              ),
              const SizedBox(height: 8),
              Text(
                'One unique ID per person. Tap a row for the internal record.',
                style: AppText.body(13, color: muted, h: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                onChanged: _onSearch,
                style: AppText.body(14, color: ink),
                decoration: InputDecoration(
                  hintText: 'Search handles',
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
              FutureBuilder<List<AdminUser>>(
                future: _users,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _InlineError(
                      message: friendlyError(snapshot.error!),
                      onRetry: _load,
                    );
                  }
                  final users = snapshot.data ?? const <AdminUser>[];
                  if (users.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No users match that search.',
                        style: AppText.body(13, color: muted),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final user in users) ...[
                        _UserTile(user: user, onTap: () => _inspect(user)),
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

class _UserTile extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final line = AppTheme.line(context);

    return Material(
      color: AppTheme.surface(context),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: Border.all(color: line)),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                color: AppTheme.bg(context),
                child: Text(
                  user.handle.isEmpty ? '?' : user.handle[0].toUpperCase(),
                  style: AppText.serif(16, color: ink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${user.handle}',
                      style: AppText.body(14, color: ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'joined ${shortDate(user.createdAt)}',
                      style: AppText.mono(10, color: muted, ls: 0.6),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user.roomCount} rooms',
                    style: AppText.body(11, color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.messageCount} messages',
                    style: AppText.body(11, color: muted),
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

class _UserSheet extends StatelessWidget {
  final AdminUser user;
  const _UserSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accent(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 42, height: 3, color: line),
          const SizedBox(height: 20),
          Text('USER RECORD', style: AppText.mono(10, color: accent, ls: 1.6)),
          const SizedBox(height: 10),
          Text('@${user.handle}', style: AppText.serif(30, color: ink)),
          const SizedBox(height: 16),
          _row(context, 'Internal id', user.id),
          _row(context, 'Joined', shortDate(user.createdAt)),
          _row(context, 'Rooms', '${user.roomCount}'),
          _row(context, 'Messages', '${user.messageCount}'),
          const SizedBox(height: 14),
          Text(
            'Anonymous messages from this user are not linked to this record '
            'anywhere in the admin screens.',
            style: AppText.body(12, color: muted, h: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label.toUpperCase(),
              style: AppText.mono(9, color: AppTheme.muted(context), ls: 1.0),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AppText.body(12, color: AppTheme.ink(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppText.body(13, color: AppTheme.muted(context)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}
