// lib/common/screens/app-shell.dart
// The signed-in app frame: Profile / Home / Search, always reachable.

import 'package:flutter/material.dart';

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
    );
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
