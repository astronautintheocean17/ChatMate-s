// test/home_hero_type_test.dart
// The home hero is the app's only book face: "Every room has a secret." and the
// paragraph under it are set in a Times-style serif, while the rest of the
// screen keeps the grotesk it always had.
import 'package:chatmate/theme/app-theme.dart';
import 'package:chatmate/users/screens/home-screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The style a [Text] actually paints with, after theme inheritance.
TextStyle _painted(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).text.style!;

void main() {
  testWidgets('the hero copy is a Times-style serif, the rest is not', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // Wide phone: the test font renders every glyph as a square, so a 360 pt
    // screen would overflow the 34 pt headline even though real fonts fit.
    tester.view.physicalSize = const Size(860, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
    );
    await tester.pump();

    // Headline: "Every room has a " in Times, "secret." in Times italic.
    final hero = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.textSpan?.toPlainText() ?? '').startsWith('Every room'),
    );
    expect(hero, findsOneWidget);

    final headline = _painted(tester, hero);
    expect(headline.fontFamily, AppText.classicFamily);
    expect(headline.fontFamilyFallback, contains('Times'));
    expect(headline.fontSize, 34);
    expect(headline.fontWeight, FontWeight.w700);

    final spans = (tester.widget<Text>(hero).textSpan! as TextSpan).children!
        .cast<TextSpan>();
    final accent = spans.last;
    expect(accent.text, 'secret.');
    expect(accent.style!.fontFamily, AppText.classicFamily);
    expect(accent.style!.fontStyle, FontStyle.italic);
    expect(accent.style!.color, AppTheme.accent(tester.element(hero)));

    // The paragraph under it inherits the same face, size and colour.
    final paragraph = _painted(
      tester,
      find.textContaining('nothing you say carries'),
    );
    expect(paragraph.fontFamily, AppText.classicFamily);
    expect(paragraph.fontSize, 12.5);

    // Everything else on the screen is still the app's grotesk.
    for (final label in ['New room', 'Enter', 'All your rooms']) {
      expect(
        _painted(tester, find.text(label)).fontFamily,
        isNot(AppText.classicFamily),
        reason: '$label should not have picked up the serif',
      );
    }
  });

  test('AppText.classic keeps the requested knobs', () {
    final style = AppText.classic(
      20,
      color: const Color(0xFF112233),
      w: FontWeight.w700,
      style: FontStyle.italic,
      h: 1.2,
      ls: 0.3,
    );
    expect(style.fontFamily, 'Times New Roman');
    expect(style.fontSize, 20);
    expect(style.color, const Color(0xFF112233));
    expect(style.fontWeight, FontWeight.w700);
    expect(style.fontStyle, FontStyle.italic);
    expect(style.height, 1.2);
    expect(style.letterSpacing, 0.3);
    // Defaults: book weight, upright, generous leading, no tracking.
    final plain = AppText.classic(12);
    expect(plain.fontWeight, FontWeight.w400);
    expect(plain.fontStyle, FontStyle.normal);
    expect(plain.height, 1.5);
    expect(plain.letterSpacing, 0);
  });
}
