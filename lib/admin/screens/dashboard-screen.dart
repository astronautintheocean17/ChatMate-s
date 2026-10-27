// lib/admin/screens/dashboard-screen.dart
import 'package:flutter/material.dart';

import '../../common/screens/landing-screen.dart';
import '../../data/admin-service.dart';
import '../../data/auth-service.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/push-service.dart';
import '../../theme/app-theme.dart';
import 'admin-rooms-screen.dart';
import 'admin-users-screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<AdminStats> _stats;

  @override
  void initState() {
    super.initState();
    _stats = AdminService.stats();
  }

  void _refresh() {
    setState(() => _stats = AdminService.stats());
  }

  Future<void> _exit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave admin?'),
        content: const Text('You will be signed out of the admin account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EXIT'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Clear this device's push token first: after signOut the row is protected
    // by RLS and this phone would keep receiving the admin's notifications.
    await PushService.signOut();
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    );
  }

  void _open(Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen)).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bg(context);
    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final accent = AppTheme.accent(context);
    final line = AppTheme.line(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 48 : 20,
              vertical: 28,
            ),
            children: [
              Row(
                children: [
                  Container(width: 9, height: 9, color: accent),
                  const SizedBox(width: 10),
                  Text(
                    'ADMIN / GHOST MODE',
                    style: AppText.mono(11, color: accent, ls: 1.6),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _exit,
                    child: Text(
                      'EXIT',
                      style: AppText.mono(11, color: muted, ls: 1.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Everything, without\na name attached.',
                style: AppText.serif(wide ? 48 : 36, color: ink, h: 1.0),
              ),
              const SizedBox(height: 12),
              Text(
                'Inspect every user and room. Anonymous senders stay anonymous, '
                'even here.',
                style: AppText.body(14, color: muted, h: 1.5),
              ),
              const SizedBox(height: 28),
              FutureBuilder<AdminStats>(
                future: _stats,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ErrorLine(
                      message: friendlyError(snapshot.error!),
                      onRetry: _refresh,
                    );
                  }
                  final stats = snapshot.data!;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Stat(label: 'USERS', value: stats.users),
                      _Stat(label: 'ROOMS', value: stats.rooms),
                      _Stat(label: 'MESSAGES', value: stats.messages),
                      _Stat(label: 'PUBLIC', value: stats.publicRooms),
                      _Stat(label: 'PRIVATE', value: stats.privateRooms),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
              Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: wide ? 1 : 0,
                    child: _AdminCard(
                      index: '01',
                      title: 'Users',
                      body: 'Every handle on the application.',
                      onTap: () => _open(const AdminUsersScreen()),
                    ),
                  ),
                  if (wide)
                    const SizedBox(width: 14)
                  else
                    const SizedBox(height: 14),
                  Expanded(
                    flex: wide ? 1 : 0,
                    child: _AdminCard(
                      index: '02',
                      title: 'Rooms',
                      body: 'Public and private rooms, ghost-readable.',
                      onTap: () => _open(const AdminRoomsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(border: Border.all(color: line)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.visibility_off_outlined, size: 18, color: muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ghost mode reads message text and membership. A sender '
                        'is only named when that sender chose "Reveal me" before '
                        'sending. This cannot be overridden.',
                        style: AppText.body(12, color: muted, h: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.mono(9, color: AppTheme.muted(context), ls: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: AppText.serif(28, color: AppTheme.ink(context), h: 1.0),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String index;
  final String title;
  final String body;
  final VoidCallback onTap;
  const _AdminCard({
    required this.index,
    required this.title,
    required this.body,
    required this.onTap,
  });

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
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(border: Border.all(color: line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(index, style: AppText.mono(10, color: accent, ls: 1.4)),
                  const Spacer(),
                  Icon(Icons.arrow_outward, size: 18, color: accent),
                ],
              ),
              const SizedBox(height: 34),
              Text(title, style: AppText.serif(30, color: ink)),
              const SizedBox(height: 6),
              Text(body, style: AppText.body(13, color: muted, h: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorLine({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
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
