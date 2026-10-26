// test/app_shell_smoke_test.dart
// Pumps the real app shell with no backend attached. Every screen catches its
// own load failures, so this proves the widget trees build and the tabs switch
// without a single thrown exception.
import 'package:chatmate/common/screens/app-shell.dart';
import 'package:chatmate/common/screens/create-id-screen.dart';
import 'package:chatmate/theme/app-theme.dart';
import 'package:chatmate/users/screens/home-screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sends the same message Android sends when the back button is pressed.
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

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

  testWidgets('back at the root tab asks before leaving the app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const AppShell()),
    );
    await tester.pump();
    expect(find.text('Leave ChatMate?'), findsNothing);

    await _pressBack(tester);
    expect(find.text('Leave ChatMate?'), findsOneWidget);

    await tester.tap(find.text('STAY'));
    await tester.pumpAndSettle();
    expect(find.text('Leave ChatMate?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back on another tab goes to Home and does not ask', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const AppShell()),
    );
    await tester.pump();

    await tester.tap(find.text('Search').last, warnIfMissed: false);
    await tester.pump();
    // Home is stacked away, so its search hint is offstage.
    expect(find.text('Search chats and groups'), findsNothing);

    await _pressBack(tester);
    expect(find.text('Leave ChatMate?'), findsNothing);
    expect(find.text('Search chats and groups'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shows the Chats / Groups switch on a phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // Wide phone: the test font renders every glyph as a square, so a 360 pt
    // screen would overflow the title even though real fonts fit.
    tester.view.physicalSize = const Size(860, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
    );
    await tester.pump();

    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(find.text('NEW GROUP'), findsOneWidget);
    expect(find.text('JOIN CODE'), findsOneWidget);
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
