// test/swipe_to_reply_test.dart
import 'package:chatmate/common/widgets/swipe-to-reply.dart';
import 'package:chatmate/theme/app-theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required void Function() onReply,
  bool enabled = true,
  String label = 'hello',
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: ListView(
        reverse: true,
        children: [
          SwipeToReply(
            itemId: 'msg-1',
            enabled: enabled,
            onReply: onReply,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(label),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('dragging a message to the right starts a reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(_harness(onReply: () => replies++));

    await tester.drag(find.text('hello'), const Offset(180, 0));
    await tester.pumpAndSettle();

    expect(replies, 1);
    // Nothing is dismissed: the message is still on screen after the gesture.
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('a short drag does not start a reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(_harness(onReply: () => replies++));

    await tester.drag(find.text('hello'), const Offset(12, 0));
    await tester.pumpAndSettle();

    expect(replies, 0);
  });

  testWidgets('a left drag is ignored', (tester) async {
    var replies = 0;
    await tester.pumpWidget(_harness(onReply: () => replies++));

    await tester.drag(find.text('hello'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(replies, 0);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('disabled rows (deleted messages) never reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(_harness(onReply: () => replies++, enabled: false));

    await tester.drag(find.text('hello'), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(replies, 0);
  });
}
