// lib/common/screens/app-shell.dart
// The signed-in app frame: Profile / Home / Search, always reachable.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app-theme.dart';
import '../../users/screens/home-screen.dart';
import '../../users/screens/profile-screen.dart';
import '../../users/screens/search-screen.dart';

enum AppTab { profile, home, search }

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = AppTab.home});

  final AppTab initialTab;

  @override
  State<AppShell> createState() => AppShellState();

  /// Jump to a tab from anywhere below the shell.
  static void open(BuildContext context, AppTab tab) {
    AppShellScope.maybeOf(context)?.open(tab);
  }
}

class AppShellState extends State<AppShell> {
  late AppTab _tab = widget.initialTab;

  void open(AppTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final index = AppTab.values.indexOf(_tab);

    return AppShellScope(
      state: this,
      child: PopScope(
        // The shell never lets the system close the app on its own: back goes
        // to the previous screen, then to Home, and only then asks to exit.
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBack();
        },
        child: Scaffold(
          backgroundColor: AppTheme.bg(context),
          body: IndexedStack(
            index: index,
            children: const [ProfileScreen(), HomeScreen(), SearchScreen()],
          ),
          bottomNavigationBar: _BottomBar(
            index: index,
            onTap: (value) => open(AppTab.values[value]),
          ),
        ),
      ),
    );
  }

  /// Android back: pop a pushed screen, else walk back to Home, else ask.
  Future<void> _handleBack() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    if (_tab != AppTab.home) {
      open(AppTab.home);
      return;
    }
    final leave = await _confirmExit();
    if (!mounted || !leave) return;
    await SystemNavigator.pop();
  }

  Future<bool> _confirmExit() async {
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

class AppShellScope extends InheritedWidget {
  const AppShellScope({super.key, required this.state, required super.child});

  final AppShellState state;

  static AppShellState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>()?.state;

  @override
  bool updateShouldNotify(AppShellScope oldWidget) => state != oldWidget.state;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
      label: 'Profile',
    ),
    (
      icon: Icons.chat_bubble_outline_rounded,
      active: Icons.chat_bubble_rounded,
      label: 'Home',
    ),
    (icon: Icons.search_rounded, active: Icons.search_rounded, label: 'Search'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.line(context))),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: i == index
                              ? accent.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Icon(
                          i == index ? _items[i].active : _items[i].icon,
                          size: 21,
                          color: i == index ? accent : AppTheme.muted(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].label,
                        style: AppText.body(
                          10,
                          color: i == index ? accent : AppTheme.muted(context),
                          w: i == index ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
