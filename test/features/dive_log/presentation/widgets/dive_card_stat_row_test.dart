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
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: DiveCardStatRow(stats: stats, diveTypeLabels: labels),
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
