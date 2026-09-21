import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_cursor_tooltip.dart';

const _plotRect = Rect.fromLTWH(0, 0, 300, 200);
const _insets = (left: 0.0, top: 0.0, right: 0.0, bottom: 0.0);

void main() {
  group('computeTooltipScaleFactor', () {
    test('returns 1.0 when the content already fits', () {
      expect(
        computeTooltipScaleFactor(naturalHeight: 100, availableHeight: 200),
        1.0,
      );
    });

    test('returns 1.0 when the content exactly fits', () {
      expect(
        computeTooltipScaleFactor(naturalHeight: 200, availableHeight: 200),
        1.0,
      );
    });

    test('shrinks proportionally when content overflows', () {
      // 100 available / 150 natural ~= 0.667, above the default 0.6 floor.
      expect(
        computeTooltipScaleFactor(naturalHeight: 150, availableHeight: 100),
        closeTo(2 / 3, 1e-9),
      );
    });

    test('floors the shrink at minScale for a pathological row count', () {
      final scale = computeTooltipScaleFactor(
        naturalHeight: 2000,
        availableHeight: 50,
        minScale: 0.6,
      );
      expect(scale, 0.6);
    });

    test('a custom minScale is respected', () {
      final scale = computeTooltipScaleFactor(
        naturalHeight: 2000,
        availableHeight: 50,
        minScale: 0.3,
      );
      expect(scale, 0.3);
    });

    test('non-positive availableHeight does not shrink (or crash)', () {
      expect(
        computeTooltipScaleFactor(naturalHeight: 100, availableHeight: 0),
        1.0,
      );
      expect(
        computeTooltipScaleFactor(naturalHeight: 100, availableHeight: -5),
        1.0,
      );
    });

    test('non-positive naturalHeight does not shrink (or crash)', () {
      expect(
        computeTooltipScaleFactor(naturalHeight: 0, availableHeight: 100),
        1.0,
      );
    });
  });

  group('computeTooltipBoxPosition', () {
    test('anchors the box gap pixels to the right of the cursor when there '
        'is room', () {
      final position = computeTooltipBoxPosition(
        cursorLocal: const Offset(50, 100),
        boxSize: const Size(80, 40),
        plotRect: _plotRect,
        gap: 8,
      );
      expect(position.dx, 50 + 8);
    });

    test('returns the box\'s bottom edge at the cursor\'s Y (the caller '
        'positions it with a `bottom` offset, so it grows upward from '
        'there using its real, as-laid-out height)', () {
      final position = computeTooltipBoxPosition(
        cursorLocal: const Offset(50, 100),
        boxSize: const Size(80, 40),
        plotRect: _plotRect,
        gap: 8,
      );
      expect(position.dy, 100);
    });

    test('still tracks the cursor near the plot\'s top edge for an '
        'ordinarily-sized box that comes nowhere near the hard ceiling', () {
      final position = computeTooltipBoxPosition(
        cursorLocal: const Offset(50, 10),
        boxSize: const Size(80, 40),
        plotRect: _plotRect,
        gap: 8,
      );
      expect(position.dy, 10);
    });

    test('detaches from the cursor once the box is tall enough that its '
        'real height would push its top past the hard ceiling -- it stops '
        'rising there instead of continuing to grow off the top of the '
        'chart entirely (issue #2228 follow-up: an earlier version had no '
        'ceiling at all here, which let the box wander arbitrarily far '
        'above the chart)', () {
      const boxHeight = 400.0;
      final position = computeTooltipBoxPosition(
        cursorLocal: const Offset(50, 10),
        boxSize: const Size(80, boxHeight),
        plotRect: _plotRect,
        gap: 8,
      );
      final ceiling = _plotRect.top - tooltipCeilingHeadroom;
      expect(position.dy, ceiling + boxHeight);
    });

    test('stops following the cursor once it goes low enough that the '
        'bottom edge would pass plotRect.bottom - tooltipTopMargin, using '
        'the same margin as the top clamp', () {
      final position = computeTooltipBoxPosition(
        cursorLocal: const Offset(50, 195),
        boxSize: const Size(80, 40),
        plotRect: _plotRect,
        gap: 8,
      );
      final maxBottom = _plotRect.bottom - tooltipTopMargin;
      expect(position.dy, maxBottom);
    });

    test('flips to the cursor\'s left side when the right edge overflows', () {
      final position = computeTooltipBoxPosition(
        cursorLocal: const Offset(280, 100),
        boxSize: const Size(80, 40),
        plotRect: _plotRect,
        gap: 8,
      );
      // Natural left (280 + 8 = 288) overflows the 300-wide plot; flipped
      // left is 280 - 8 - 80 = 192, which fits.
      expect(position.dx, 280 - 8 - 80);
    });

    test(
      'clamps to the right edge when even the flipped placement overflows',
      () {
        final position = computeTooltipBoxPosition(
          cursorLocal: const Offset(40, 100),
          boxSize: const Size(280, 40),
          plotRect: _plotRect,
          gap: 8,
        );
        // Flipped left (40 - 8 - 280 = -248) is off the left edge too, so
        // the box must clamp to the plot's right edge instead.
        expect(position.dx, _plotRect.right - 280);
      },
    );

    test('never places the box left of the plot rect', () {
      final position = computeTooltipBoxPosition(
        cursorLocal: const Offset(-50, 100),
        boxSize: const Size(80, 40),
        plotRect: _plotRect,
        gap: 8,
      );
      expect(position.dx, greaterThanOrEqualTo(_plotRect.left));
    });

    test('a box wider than the plot rect still returns a finite position', () {
      final position = computeTooltipBoxPosition(
        cursorLocal: const Offset(50, 100),
        boxSize: const Size(400, 40),
        plotRect: _plotRect,
        gap: 8,
      );
      expect(position.dx.isFinite, isTrue);
    });
  });

  group('ProfileCursorTooltip widget', () {
    Widget harness({
      required List<TooltipRow> rows,
      Offset cursorLocal = const Offset(100, 100),
      ProfileRightAxisMetric? highlightedMetric,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: ProfileCursorTooltip(
              rows: rows,
              cursorLocal: cursorLocal,
              insets: _insets,
              highlightedMetric: highlightedMetric,
            ),
          ),
        ),
      );
    }

    testWidgets('renders nothing for an empty row list', (tester) async {
      await tester.pumpWidget(harness(rows: const []));
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('the rendered box\'s actual bottom edge lands exactly at the '
        'cursor\'s Y, not merely at top + an estimated height (issue #2228 '
        'follow-up: the estimate can differ from the real, as-laid-out '
        'height, leaving the bottom edge adrift from the cursor)', (
      tester,
    ) async {
      const cursorLocal = Offset(100, 120);
      await tester.pumpWidget(
        harness(
          rows: const [
            TooltipRow(
              label: 'Time',
              value: '1:23',
              bulletColor: AppColors.chartDepth,
            ),
            TooltipRow(
              label: 'Depth',
              value: '12.3 m',
              bulletColor: AppColors.chartDepth,
            ),
          ],
          cursorLocal: cursorLocal,
        ),
      );

      final containerTop = tester
          .getTopLeft(find.byType(ProfileCursorTooltip))
          .dy;
      final boxBottom = tester.getRect(find.byType(DecoratedBox).first).bottom;
      expect(boxBottom, closeTo(containerTop + cursorLocal.dy, 0.5));
    });

    testWidgets('renders each row\'s label and value', (tester) async {
      await tester.pumpWidget(
        harness(
          rows: const [
            TooltipRow(
              label: 'Time',
              value: '1:23',
              bulletColor: AppColors.chartDepth,
            ),
            TooltipRow(
              label: 'Depth',
              value: '12.3 m',
              bulletColor: AppColors.chartDepth,
            ),
          ],
        ),
      );

      expect(find.text('Time'), findsOneWidget);
      expect(find.text('1:23'), findsOneWidget);
      expect(find.text('Depth'), findsOneWidget);
      expect(find.text('12.3 m'), findsOneWidget);
    });

    testWidgets('renders without throwing for a large row count', (
      tester,
    ) async {
      final rows = [
        for (var i = 0; i < 40; i++)
          TooltipRow(
            label: 'Metric $i',
            value: '$i.0',
            bulletColor: AppColors.chartDepth,
          ),
      ];
      await tester.pumpWidget(harness(rows: rows));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Metric 0'), findsOneWidget);
    });

    testWidgets('shrinks the box width along with the text once row count '
        'outgrows the available height, instead of staying as wide as the '
        'whole plot while only the text shrinks (issue #2228 follow-up)', (
      tester,
    ) async {
      final fewRows = [
        for (var i = 0; i < 2; i++)
          TooltipRow(
            label: 'Metric $i',
            value: '$i.0',
            bulletColor: AppColors.chartDepth,
          ),
      ];
      await tester.pumpWidget(harness(rows: fewRows));
      await tester.pump();
      final unshrunkWidth = tester
          .getRect(find.byType(DecoratedBox).first)
          .width;

      final manyRows = [
        for (var i = 0; i < 40; i++)
          TooltipRow(
            label: 'Metric $i',
            value: '$i.0',
            bulletColor: AppColors.chartDepth,
          ),
      ];
      await tester.pumpWidget(harness(rows: manyRows));
      await tester.pump();
      final shrunkWidth = tester.getRect(find.byType(DecoratedBox).first).width;

      expect(shrunkWidth, lessThan(unshrunkWidth));
    });

    testWidgets('the box\'s bottom edge stays exactly at the cursor for an '
        'ordinary row count nowhere near the hard ceiling', (tester) async {
      const cursorLocal = Offset(100, 10);
      const rows = [
        TooltipRow(label: 'Time', value: '1:23', bulletColor: Colors.blue),
        TooltipRow(label: 'Depth', value: '12.3 m', bulletColor: Colors.blue),
        TooltipRow(label: 'Temp', value: '18°C', bulletColor: Colors.blue),
      ];
      await tester.pumpWidget(harness(rows: rows, cursorLocal: cursorLocal));
      await tester.pump();

      final containerTop = tester
          .getTopLeft(find.byType(ProfileCursorTooltip))
          .dy;
      final boxBottom = tester.getRect(find.byType(DecoratedBox).first).bottom;
      expect(boxBottom, closeTo(containerTop + cursorLocal.dy, 0.5));
    });

    testWidgets('detaches from the cursor once enough rows are active that the '
        'box\'s real height would carry it past its hard ceiling, instead '
        'of continuing to rise indefinitely (issue #2228 follow-up)', (
      tester,
    ) async {
      const cursorLocal = Offset(100, 10);
      final rows = [
        for (var i = 0; i < 60; i++)
          TooltipRow(
            label: 'Metric $i',
            value: '$i.0',
            bulletColor: AppColors.chartDepth,
          ),
      ];
      await tester.pumpWidget(harness(rows: rows, cursorLocal: cursorLocal));
      await tester.pump();

      final containerTop = tester
          .getTopLeft(find.byType(ProfileCursorTooltip))
          .dy;
      final boxBottom = tester.getRect(find.byType(DecoratedBox).first).bottom;
      // Had it kept tracking the cursor, the bottom would sit right at
      // containerTop + 10; the ceiling instead holds it well below that
      // (bottom = ceiling + box height), clear evidence it detached.
      expect(boxBottom, greaterThan(containerTop + 50));
    });

    testWidgets('bolds the label of the row matching highlightedMetric, leaves '
        'others normal', (tester) async {
      await tester.pumpWidget(
        harness(
          rows: const [
            TooltipRow(
              label: 'Temp.',
              value: '15°C',
              bulletColor: AppColors.chartDepth,
              metric: ProfileRightAxisMetric.temperature,
            ),
            TooltipRow(
              label: 'CNS',
              value: '37.0%',
              bulletColor: AppColors.chartDepth,
              metric: ProfileRightAxisMetric.cns,
            ),
          ],
          highlightedMetric: ProfileRightAxisMetric.cns,
        ),
      );

      final tempLabel = tester.widget<Text>(find.text('Temp.'));
      final cnsLabel = tester.widget<Text>(find.text('CNS'));
      expect(tempLabel.style?.fontWeight, isNot(FontWeight.bold));
      expect(cnsLabel.style?.fontWeight, FontWeight.bold);

      // The value column matches the label column (issue #2228 follow-up):
      // previously every value rendered bold unconditionally, unlike the
      // native bubble used on the dive detail page, where only the
      // highlighted row's text is bold.
      final tempValue = tester.widget<Text>(find.text('15°C'));
      final cnsValue = tester.widget<Text>(find.text('37.0%'));
      expect(tempValue.style?.fontWeight, isNot(FontWeight.bold));
      expect(cnsValue.style?.fontWeight, FontWeight.bold);
    });
  });
}
