import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_bar_label_fit.dart';

/// Lays [text] out at [fontSize] within [maxWidth] and counts its lines.
int _lineCount(
  String text, {
  required double fontSize,
  required double maxWidth,
  TextScaler textScaler = TextScaler.noScaling,
  double? letterSpacing,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, letterSpacing: letterSpacing),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

/// Adds a fixed amount to every size, so small text grows proportionally
/// more than large text, as Android's nonlinear font scaling does.
class _AddingTextScaler extends TextScaler {
  const _AddingTextScaler(this.amount);

  final double amount;

  @override
  double scale(double fontSize) => fontSize + amount;

  @override
  double get textScaleFactor => 1;
}

/// Builds the bar's fitted label style under [theme] and [padding].
Future<WidgetStateProperty<TextStyle?>?> _fittedStyle(
  WidgetTester tester, {
  required List<String> labels,
  required double barWidth,
  ThemeData? theme,
  EdgeInsets padding = EdgeInsets.zero,
  TextStyle ambient = const TextStyle(),
}) async {
  WidgetStateProperty<TextStyle?>? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(padding: padding),
        child: DefaultTextStyle.merge(
          style: ambient,
          child: Builder(
            builder: (context) {
              result = fittedNavBarLabelTextStyle(
                context,
                labels: labels,
                barWidth: barWidth,
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );
  return result;
}

void main() {
  // The test font draws every glyph one em wide, so a word of n letters at
  // font size s is exactly n * s wide.
  const base = TextStyle(fontSize: 12);

  group('fitNavBarLabelScale', () {
    test('keeps full size when every word fits its slot', () {
      final scale = fitNavBarLabelScale(
        labels: const ['Home', 'Dives', 'Sites'],
        styles: const [base],
        slotWidth: 75,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
      );

      expect(scale, 1.0);
    });

    test('shrinks until the longest word fits on one line (#4336)', () {
      const slotWidth = 100.0;
      final scale = fitNavBarLabelScale(
        labels: const ['Startseite', 'Tauchgänge', 'Tauchplätze', 'Mehr'],
        styles: const [base],
        slotWidth: slotWidth,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
        minFontSize: 6,
      );

      expect(scale, lessThan(1.0));
      // Before the fix "Tauchplätze" split mid-word at full size.
      expect(_lineCount('Tauchplätze', fontSize: 12, maxWidth: slotWidth), 2);
      expect(
        _lineCount('Tauchplätze', fontSize: 12 * scale, maxWidth: slotWidth),
        1,
      );
    });

    test('measures words, so a multi-word label may wrap between them', () {
      final scale = fitNavBarLabelScale(
        labels: const ['Dive Centers'],
        styles: const [base],
        slotWidth: 90,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
        minFontSize: 6,
      );

      // "Centers" (84 wide) fits 90 at full size; the whole label (144)
      // would not, and is left to wrap at the space.
      expect(scale, 1.0);
    });

    test('never shrinks below the minimum font size', () {
      final scale = fitNavBarLabelScale(
        labels: const ['Merülőcentrumok'],
        styles: const [base],
        slotWidth: 60,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
        minFontSize: 9,
      );

      expect(12 * scale, closeTo(9, 0.001));
    });

    test('never grows a style that is already below the minimum', () {
      final scale = fitNavBarLabelScale(
        labels: const ['Tauchplätze'],
        styles: const [TextStyle(fontSize: 8)],
        slotWidth: 40,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
        minFontSize: 9,
      );

      expect(scale, 1.0);
    });

    test('accounts for the text scaler the label is drawn with', () {
      const slotWidth = 75.0;
      const scaler = TextScaler.linear(1.3);
      final plain = fitNavBarLabelScale(
        labels: const ['Dives'],
        styles: const [base],
        slotWidth: slotWidth,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
        minFontSize: 4,
      );
      final scaled = fitNavBarLabelScale(
        labels: const ['Dives'],
        styles: const [base],
        slotWidth: slotWidth,
        textScaler: scaler,
        textDirection: TextDirection.ltr,
        minFontSize: 4,
      );

      expect(plain, 1.0);
      expect(scaled, lessThan(1.0));
      expect(
        _lineCount(
          'Dives',
          fontSize: 12 * scaled,
          maxWidth: slotWidth,
          textScaler: scaler,
        ),
        1,
      );
    });

    test('fits the widest of the styles it is given', () {
      final scale = fitNavBarLabelScale(
        labels: const ['Reisen'],
        styles: const [TextStyle(fontSize: 10), TextStyle(fontSize: 12)],
        slotWidth: 60,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
        minFontSize: 4,
      );

      // At 12, "Reisen" is 72 wide; it needs 60 / 72 of that.
      expect(scale, lessThan(60 / 72 + 0.001));
      expect(_lineCount('Reisen', fontSize: 12 * scale, maxWidth: 60), 1);
    });

    test('ignores empty labels and a zero-width slot', () {
      expect(
        fitNavBarLabelScale(
          labels: const ['', '  '],
          styles: const [base],
          slotWidth: 75,
          textScaler: TextScaler.noScaling,
          textDirection: TextDirection.ltr,
        ),
        1.0,
      );
      expect(
        fitNavBarLabelScale(
          labels: const ['Dives'],
          styles: const [base],
          slotWidth: 0,
          textScaler: TextScaler.noScaling,
          textDirection: TextDirection.ltr,
        ),
        1.0,
      );
    });
    test('fits under a nonlinear text scaler', () {
      const slotWidth = 75.0;
      const scaler = _AddingTextScaler(6);
      final scale = fitNavBarLabelScale(
        labels: const ['Dives'],
        styles: const [base],
        slotWidth: slotWidth,
        textScaler: scaler,
        textDirection: TextDirection.ltr,
        minFontSize: 4,
      );

      // A factor of slot / width (74 / 90) would draw at 15.9 and still
      // split; the fitted size has to account for the added 6.
      expect(
        _lineCount(
          'Dives',
          fontSize: 12 * scale,
          maxWidth: slotWidth,
          textScaler: scaler,
        ),
        1,
      );
    });

    test('keeps words joined by a no-break space together', () {
      final joined = fitNavBarLabelScale(
        labels: const ['Sites\u00A0de'],
        styles: const [base],
        slotWidth: 75,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
        minFontSize: 4,
      );
      final spaced = fitNavBarLabelScale(
        labels: const ['Sites de'],
        styles: const [base],
        slotWidth: 75,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
        minFontSize: 4,
      );

      expect(spaced, 1.0);
      expect(joined, lessThan(1.0));
    });
  });

  group('fittedNavBarLabelTextStyle', () {
    // Five labels whose longest word, "Dives", is 60 wide at 12.
    const labels = ['Home', 'Dives', 'Sites', 'Trips', 'More'];

    testWidgets('keeps the default style when the words fit', (tester) async {
      final style = await _fittedStyle(tester, labels: labels, barWidth: 375);

      expect(style, isNull);
    });

    testWidgets('takes the safe-area insets off the bar', (tester) async {
      final style = await _fittedStyle(
        tester,
        labels: labels,
        barWidth: 375,
        // A landscape notch: 375 less 100 leaves 55 a slot.
        padding: const EdgeInsets.symmetric(horizontal: 50),
      );

      expect(
        style!.resolve(<WidgetState>{})!.fontSize,
        lessThanOrEqualTo(12 * 54 / 60),
      );
    });

    testWidgets('takes the theme label padding off each slot', (tester) async {
      final style = await _fittedStyle(
        tester,
        labels: labels,
        barWidth: 375,
        theme: ThemeData(
          navigationBarTheme: const NavigationBarThemeData(
            labelPadding: EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      );

      // 75 a slot less 20 of padding leaves 55.
      expect(
        style!.resolve(<WidgetState>{})!.fontSize,
        lessThanOrEqualTo(12 * 54 / 60),
      );
    });

    testWidgets('measures the label merged over the ambient style', (
      tester,
    ) async {
      // The themed style leaves letter spacing to the ambient style, which
      // widens "Dives" from 60 to 80, past the 74 a slot has to spare.
      final style = await _fittedStyle(
        tester,
        labels: labels,
        barWidth: 375,
        ambient: const TextStyle(letterSpacing: 4),
        theme: ThemeData(
          navigationBarTheme: const NavigationBarThemeData(
            labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
          ),
        ),
      );

      expect(style, isNotNull);
      final fontSize = style!.resolve(<WidgetState>{})!.fontSize!;
      expect(fontSize, lessThan(12));
      // The spacing does not shrink with the font, so a size scaled by
      // 74 / 80 alone (11.1, drawing 75.5 wide) would still wrap.
      expect(
        _lineCount('Dives', fontSize: fontSize, maxWidth: 75, letterSpacing: 4),
        1,
      );
    });
  });
}
