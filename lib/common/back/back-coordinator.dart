// lib/common/back/back-coordinator.dart
// One back button for the whole app.
//
// Every system back press lands in the same place: the PopScope on the root
// route (see common/widgets/app-exit-guard.dart). That handler walks a stack of
// interceptors registered by whatever is currently on screen, and only when
// nobody claims the press does it ask the user whether ChatMate should close.
//
// Nothing in the app calls SystemNavigator.pop() except this file, so no screen
// can close ChatMate by accident — not the landing screen, not the session
// gate, not a pushed room.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app-theme.dart';

/// Returns true when the press was handled and the app must stay open.
typedef BackInterceptor = FutureOr<bool> Function();

class BackCoordinator {
  BackCoordinator._();

  /// There is exactly one back button per process.
  static final BackCoordinator instance = BackCoordinator._();

  final List<BackInterceptor> _interceptors = <BackInterceptor>[];
  bool _asking = false;

  /// Screens register while they are mounted. Newest first, like the visual
  /// stack: the screen the user is looking at gets the first say.
  Object register(BackInterceptor interceptor) {
    _interceptors.add(interceptor);
    return interceptor;
  }

  void unregister(Object token) {
    _interceptors.remove(token);
  }

  /// Number of live interceptors. Used by tests to prove nothing leaks.
  int get interceptorCount => _interceptors.length;

  /// Test-only: drop every interceptor so one test cannot leak into the next.
  @visibleForTesting
  void clear() {
    _interceptors.clear();
    _asking = false;
  }

  /// True while the "Leave ChatMate?" dialog is on screen.
  bool get isAsking => _asking;

  /// Entry point for every system back press that reached the root route.
  Future<void> handle(BuildContext context) async {
    // A second press while the dialog is open must not stack another dialog.
    if (_asking) return;

    for (final interceptor in _interceptors.reversed.toList(growable: false)) {
      if (await interceptor()) return;
    }

    if (!context.mounted) return;

    _asking = true;
    final leave = await confirmExit(context);
    _asking = false;
    if (!leave) return;

    await SystemNavigator.pop();
  }

  /// The one exit dialog: every screen asks the same question, in the same
  /// voice, and nothing closes the app before an explicit EXIT.
  Future<bool> confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface(dialogContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Leave ChatMate?',
          style: AppText.serif(20, color: AppTheme.ink(dialogContext)),
        ),
        content: Text(
          'You will not get new messages until you open the app again.',
          style: AppText.body(
            12.5,
            color: AppTheme.muted(dialogContext),
            h: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'STAY',
              style: AppText.mono(10, color: AppTheme.muted(dialogContext)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'EXIT',
              style: AppText.mono(10, color: AppTheme.accent(dialogContext)),
            ),
          ),
        ],
      ),
    );
    return leave ?? false;
  }
}
