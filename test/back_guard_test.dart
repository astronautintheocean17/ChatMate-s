// test/back_guard_test.dart
// One back button, one rule: the system back press may never close ChatMate
// without the user choosing EXIT. These tests press the same platform button
// Android presses and watch what the app does with it.
import 'package:chatmate/common/back/back-coordinator.dart';
import 'package:chatmate/common/widgets/app-exit-guard.dart';
import 'package:chatmate/theme/app-theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final platformCalls = <String>[];

  setUp(() {
    // The coordinator is a process-wide singleton; start every test clean.
    BackCoordinator.instance.clear();
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpRoot(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppExitGuard(child: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('back on a plain screen asks before closing the app', (
    tester,
  ) async {
    await pumpRoot(tester, const Scaffold(body: Text('Landing')));

    expect(find.text('Leave ChatMate?'), findsNothing);
    await _pressBack(tester);

    expect(find.text('Leave ChatMate?'), findsOneWidget);
    expect(find.text('STAY'), findsOneWidget);
    expect(find.text('EXIT'), findsOneWidget);
    // The dialog is up: nothing has told the system to close the app.
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });

  testWidgets('STAY keeps the app open', (tester) async {
    await pumpRoot(tester, const Scaffold(body: Text('Landing')));

    await _pressBack(tester);
    await tester.tap(find.text('STAY'));
    await tester.pumpAndSettle();

    expect(find.text('Leave ChatMate?'), findsNothing);
    expect(find.text('Landing'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });

  testWidgets('EXIT closes only after the dialog says so', (tester) async {
    await pumpRoot(tester, const Scaffold(body: Text('Landing')));

    await _pressBack(tester);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await tester.tap(find.text('EXIT'));
    await tester.pumpAndSettle();

    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets(
    'a second press dismisses the question and keeps the app open',
    (tester) async {
      await pumpRoot(tester, const Scaffold(body: Text('Landing')));

      await _pressBack(tester);
      expect(find.text('Leave ChatMate?'), findsOneWidget);

      // Back on a dialog behaves like STAY: it closes the dialog, not the app.
      await _pressBack(tester);
      expect(find.text('Leave ChatMate?'), findsNothing);
      expect(find.text('Landing'), findsOneWidget);
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));
    },
  );

  testWidgets('an interceptor can claim the press before the exit question', (
    tester,
  ) async {
    var handled = false;
    BackCoordinator.instance.register(() {
      handled = true;
      return true;
    });

    await pumpRoot(tester, const Scaffold(body: Text('Landing')));
    await _pressBack(tester);

    expect(handled, isTrue);
    expect(find.text('Leave ChatMate?'), findsNothing);
  });

  testWidgets('a released interceptor no longer runs', (tester) async {
    var handled = false;
    final token = BackCoordinator.instance.register(() {
      handled = true;
      return true;
    });
    BackCoordinator.instance.unregister(token);
    expect(BackCoordinator.instance.interceptorCount, 0);

    await pumpRoot(tester, const Scaffold(body: Text('Landing')));
    await _pressBack(tester);

    expect(handled, isFalse);
    expect(find.text('Leave ChatMate?'), findsOneWidget);
  });

  testWidgets('back inside a pushed screen pops that screen, not the app', (
    tester,
  ) async {
    await pumpRoot(tester, const Scaffold(body: Text('Landing')));

    final context = tester.element(find.text('Landing'));
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Second'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);

    await _pressBack(tester);
    expect(find.text('Second'), findsNothing);
    expect(find.text('Landing'), findsOneWidget);
    expect(find.text('Leave ChatMate?'), findsNothing);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });
}
