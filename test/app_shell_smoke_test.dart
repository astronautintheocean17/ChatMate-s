// test/app_shell_smoke_test.dart
// Pumps the real app shell with no backend attached. Every screen catches its
// own load failures, so this proves the widget trees build and the tabs switch
// without a single thrown exception.
import 'package:chatmate/common/screens/app-shell.dart';
import 'package:chatmate/common/screens/create-id-screen.dart';
import 'package:chatmate/theme/app-theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the three tabs build and switch cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const AppShell()),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Home → Search → Profile, then back to Home.
    for (final label in ['Search', 'Profile', 'Home']) {
      final tab = find.text(label).last;
      expect(tab, findsOneWidget, reason: 'missing $label tab');
      await tester.tap(tab, warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'tab $label threw');
    }

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('create id renders in ${mode.name} mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const CreateIdScreen(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Pick your ChatMate ID'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('CHATMATE ID'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
