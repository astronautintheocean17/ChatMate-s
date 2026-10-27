// lib/common/widgets/app-exit-guard.dart
// Wraps the root route so the Android back button (and the desktop escape key)
// can never close ChatMate on its own.
//
// Put it directly around the app's `home:` widget:
//
//   MaterialApp(home: AppExitGuard(child: SessionGate()))
//
// Pushed routes still pop normally. When there is nothing left to pop, the
// press is handed to BackCoordinator, which asks "Leave ChatMate?" first.

import 'package:flutter/material.dart';

import '../back/back-coordinator.dart';

class AppExitGuard extends StatelessWidget {
  const AppExitGuard({super.key, required this.child});

  final Widget child;

  /// Ask the exit question from anywhere (a menu item, a "close" button...).
  static Future<void> request(BuildContext context) =>
      BackCoordinator.instance.handle(context);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: false is what stops the system from killing the activity.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        BackCoordinator.instance.handle(context);
      },
      child: child,
    );
  }
}
