import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipRow;
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_tooltip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_cursor_tooltip.dart';

void main() {
  group('pinnedTooltipLeft', () {
    test('left of the box is 10 px right of the cursor', () {
      expect(
        pinnedTooltipLeft(cursorX: 100, tooltipWidth: 120, stripWidth: 390),
        110,
      );
    });

    test('flips left near the right edge', () {
      expect(
        pinnedTooltipLeft(cursorX: 300, tooltipWidth: 120, stripWidth: 390),
        170,
      );
    });

    test('stays on screen at the right edge', () {
      final left = pinnedTooltipLeft(
        cursorX: 389,
        tooltipWidth: 120,
        stripWidth: 390,
      );
      expect(left, lessThanOrEqualTo(390 - 8 - 120));
      expect(left, greaterThanOrEqualTo(8));
    });

    test('stays on screen when wider than the room either side', () {
      expect(
        pinnedTooltipLeft(cursorX: 100, tooltipWidth: 300, stripWidth: 320),
        8,
      );
    });

    test('a box wider than the strip starts at its edge', () {
      expect(
        pinnedTooltipLeft(cursorX: 50, tooltipWidth: 500, stripWidth: 320),
        8,
      );
    });
  });

  testWidgets("renders a row's label and value with its bullet colour", (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: PinnedStripTooltip(
            rows: [
              TooltipRow(
                label: 'NDL',
                value: '14 min',
                bulletColor: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('NDL'), findsOneWidget);
    expect(find.text('14 min'), findsOneWidget);
    final bullet = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('pinnedTooltipBullet0')),
    );
    expect((bullet.decoration as BoxDecoration).color, Colors.amber);
    final box = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('pinnedTooltipBox')),
    );
    expect((box.decoration as BoxDecoration).color, tooltipBackgroundColor);
  });
}
