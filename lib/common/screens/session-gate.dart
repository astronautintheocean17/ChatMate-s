// lib/common/screens/session-gate.dart
import 'package:flutter/material.dart';

import '../../admin/screens/dashboard-screen.dart';
import '../../data/auth-service.dart';
import '../../data/errors.dart';
import '../../data/profile-service.dart';
import '../../theme/app-theme.dart';
import '../../users/screens/home-screen.dart';
import 'create-id-screen.dart';
import 'landing-screen.dart';

/// Decides where a cold start goes:
/// landing -> no session, create-id -> session without a handle,
/// home -> normal user, admin dashboard -> admin session.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  Widget? _destination;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() {
      _destination = null;
      _error = null;
    });

    try {
      if (!AuthService.hasSession || AuthService.currentUser == null) {
        if (!mounted) return;
        setState(() => _destination = const LandingScreen());
        return;
      }

      if (AuthService.isAdmin) {
        if (!mounted) return;
        setState(() => _destination = const AdminHomeScreen());
        return;
      }

      final profile = await ProfileService.current();
      if (!mounted) return;
      setState(() {
        _destination =
            profile == null ? const CreateIdScreen() : const HomeScreen();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    if (destination != null) return destination;

    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final accent = AppTheme.accent(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CHATMATE',
              style: AppText.mono(12, color: accent, ls: 3),
            ),
            const SizedBox(height: 18),
            if (_error == null)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.body(13, color: muted),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _resolve,
                child: Text('TRY AGAIN', style: AppText.mono(11, color: ink)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
