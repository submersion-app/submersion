import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_card_stat_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';

void main() {
  group('DiveCardStatRow.fairShareWidths', () {
    test('every stat keeps its natural width when they all fit', () {
      expect(DiveCardStatRow.fairShareWidths([40, 60], 200), [40, 60]);
    });

    test('a stat narrower than half keeps it, the other takes the rest', () {
      expect(DiveCardStatRow.fairShareWidths([40, 300], 200), [40, 160]);
      expect(DiveCardStatRow.fairShareWidths([300, 40], 200), [160, 40]);
    });

    test('two stats both wider than half split the budget evenly', () {
      expect(DiveCardStatRow.fairShareWidths([150, 300], 200), [100, 100]);
    });

    test('a non-positive budget gives every stat zero width', () {
      expect(DiveCardStatRow.fairShareWidths([40, 60], -10), [0, 0]);
    });
  });

  group('DiveCardStatRow layout', () {
    const labels = ['Wreck', 'Night', 'Drift', 'Tec'];
    const long = 'Wreck, Night, Drift, Technical, Cave, Deep, Boat, Shore';

    Future<void> pumpRow(
      WidgetTester tester, {
      required double width,
      required List<DiveCardStat> stats,
      List<String> diveTypeLabels = labels,
      double textScale = 1,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: DiveCardStatRow(
                  stats: stats,
                  diveTypeLabels: diveTypeLabels,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the badges keep room for their collapsed badge', (
      tester,
    ) async {
      for (var width = 120.0; width <= 400; width += 10) {
        await pumpRow(
          tester,
          width: width,
          stats: const [
            DiveCardStat(icon: Icons.arrow_downward, text: '131.4m'),
            DiveCardStat(text: long),
          ],
        );
        expect(tester.takeException(), isNull, reason: 'at ${width}px');
        expect(find.byType(DiveTypeBadgeRow), findsOneWidget);
      }
    });

    testWidgets('the badge reservation follows the text scale', (tester) async {
      // The collapsed "+N" badge grows with the text scale, so a reservation
      // measured at the default scale would leave it too little room.
      for (var width = 120.0; width <= 400; width += 10) {
        await pumpRow(
          tester,
          width: width,
          textScale: 2,
          stats: const [
            DiveCardStat(icon: Icons.arrow_downward, text: '131.4m'),
            DiveCardStat(text: long),
          ],
        );
        expect(tester.takeException(), isNull, reason: 'at ${width}px');
      }
    });

    testWidgets('a slot keeps its icon while the icon itself fits', (
      tester,
    ) async {
      const stats = [
        DiveCardStat(icon: Icons.arrow_downward, text: long),
        DiveCardStat(icon: Icons.timer_outlined, text: long),
      ];
      // No badges: each slot gets (width - 16px gap) / 2, so these widths
      // sweep the slots through 10-20px, across the icon's own 14px and the
      // icon plus its 4px gap.
      for (var width = 36.0; width <= 56; width += 1) {
        await pumpRow(
          tester,
          width: width,
          stats: stats,
          diveTypeLabels: const [],
        );
        final slot = (width - 16) / 2;
        expect(tester.takeException(), isNull, reason: 'at ${width}px');
        expect(
          find.byType(Icon),
          slot >= 14 ? findsNWidgets(2) : findsNothing,
          reason: 'slot ${slot}px',
        );
      }
    });

    testWidgets('a short stat is not truncated by a long neighbor', (
      tester,
    ) async {
      await pumpRow(
        tester,
        width: 280,
        stats: const [
          DiveCardStat(icon: Icons.arrow_downward, text: '131.4m'),
          DiveCardStat(text: long),
        ],
      );

      final depth = tester.renderObject<RenderParagraph>(find.text('131.4m'));
      expect(depth.didExceedMaxLines, isFalse);
      final other = tester.renderObject<RenderParagraph>(find.text(long));
      expect(other.didExceedMaxLines, isTrue);
    });

    testWidgets('stats render at full width when the line is wide', (
      tester,
    ) async {
      await pumpRow(
        tester,
        width: 600,
        stats: const [
          DiveCardStat(icon: Icons.arrow_downward, text: '131.4m'),
          DiveCardStat(icon: Icons.timer_outlined, text: '147 min'),
        ],
      );

      for (final text in ['131.4m', '147 min']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
      }
    });
  });
}
