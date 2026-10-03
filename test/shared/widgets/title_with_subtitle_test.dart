import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/models/subtitle_text.dart';
import 'package:submersion/shared/widgets/title_with_subtitle.dart';

Widget _inBox(
  double width,
  SubtitleText? subtitle, {
  double subtitleIndent = 0,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: TitleWithSubtitle(
          title: const Text('Dives'),
          subtitle: subtitle,
          subtitleIndent: subtitleIndent,
        ),
      ),
    ),
  ),
);

const _count = SubtitleText('34 of 812 dives', compact: '34 of 812');

void main() {
  testWidgets('shows the full subtitle where it fits', (tester) async {
    await tester.pumpWidget(_inBox(400, _count));

    expect(find.text('34 of 812 dives'), findsOneWidget);
    expect(find.text('34 of 812'), findsNothing);
  });

  // A phone app bar with six actions leaves the title about 86px; the count
  // drops its noun there rather than ellipsising the number away (#2669).
  testWidgets('falls back to the compact form where it does not', (
    tester,
  ) async {
    final fullWidth = await _fullWidth(tester);
    await tester.pumpWidget(_inBox(fullWidth - 1, _count));

    expect(find.text('34 of 812'), findsOneWidget);
    expect(find.text('34 of 812 dives'), findsNothing);
  });

  testWidgets('keeps the full form at exactly its own width', (tester) async {
    final fullWidth = await _fullWidth(tester);
    await tester.pumpWidget(_inBox(fullWidth.ceilToDouble(), _count));

    expect(find.text('34 of 812 dives'), findsOneWidget);
  });

  testWidgets('ellipsises the full form when there is no compact one', (
    tester,
  ) async {
    await tester.pumpWidget(_inBox(40, const SubtitleText('34 of 812 dives')));

    final text = tester.widget<Text>(find.text('34 of 812 dives'));
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('returns the title alone without a subtitle', (tester) async {
    await tester.pumpWidget(_inBox(400, null));

    expect(find.byType(Text), findsOneWidget);
    expect(find.byType(Column), findsNothing);
  });

  testWidgets('subtitleIndent starts the subtitle that far in', (tester) async {
    await tester.pumpWidget(_inBox(400, _count, subtitleIndent: 8));

    expect(
      tester.getTopLeft(find.text('34 of 812 dives')).dx -
          tester.getTopLeft(find.text('Dives')).dx,
      8,
    );
  });

  // The indent comes out of the width the full form has to fit in.
  testWidgets('measures the fit in the width left after the indent', (
    tester,
  ) async {
    final fullWidth = await _fullWidth(tester);
    await tester.pumpWidget(
      _inBox(fullWidth.ceilToDouble() + 4, _count, subtitleIndent: 8),
    );

    expect(find.text('34 of 812'), findsOneWidget);
  });

  // A fixed-height host sizes itself from this, so it has to match the line
  // as rendered, text scale included (#2776).
  for (final scale in <double>[1, 1.5]) {
    testWidgets('subtitleLineHeight matches the rendered line at ${scale}x', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_inBox(400, _count));

      final rendered = tester.getSize(find.text('34 of 812 dives')).height;
      final measured = TitleWithSubtitle.subtitleLineHeight(
        tester.element(find.text('34 of 812 dives')),
        text: '34 of 812 dives',
      );
      expect(measured, closeTo(rendered, 0.5));
    });
  }
}

/// The rendered width of the full subtitle, measured unconstrained.
Future<double> _fullWidth(WidgetTester tester) async {
  await tester.pumpWidget(_inBox(1000, _count));
  return tester.getSize(find.text('34 of 812 dives')).width;
}
