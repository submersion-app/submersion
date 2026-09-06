import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/range_selection_overlay.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  // A 400x300 chart with the profile chart's real gutters: the plot rect
  // runs from x = 48 to x = 346 and from y = 0 to y = 204.
  const insets = (left: 48.0, top: 0.0, right: 54.0, bottom: 96.0);
  const plotLeft = 48.0;
  const plotWidth = 298.0;

  Future<void> pumpOverlay(
    WidgetTester tester, {
    int startSeconds = 900,
    int endSeconds = 2700,
    int maxSeconds = 3600,
    double visibleMinSeconds = 0,
    double visibleMaxSeconds = 3600,
    void Function(int start, int end)? onRangeChanged,
    void Function(bool active)? onDragActiveChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: RangeSelectionOverlay(
              startSeconds: startSeconds,
              endSeconds: endSeconds,
              maxSeconds: maxSeconds,
              visibleMinSeconds: visibleMinSeconds,
              visibleMaxSeconds: visibleMaxSeconds,
              insets: insets,
              onRangeChanged: onRangeChanged ?? (_, _) {},
              onDragActiveChanged: onDragActiveChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('handle placement', () {
    testWidgets('the dive start sits on the plot rect edge, not left of it', (
      tester,
    ) async {
      await pumpOverlay(tester, startSeconds: 0, endSeconds: 3600);

      expect(
        tester.getCenter(find.byKey(RangeSelectionOverlay.startHandleKey)).dx,
        closeTo(plotLeft, 0.001),
      );
      expect(
        tester.getCenter(find.byKey(RangeSelectionOverlay.endHandleKey)).dx,
        closeTo(plotLeft + plotWidth, 0.001),
      );
    });

    testWidgets('places handles at their timestamps inside the plot rect', (
      tester,
    ) async {
      await pumpOverlay(tester);

      expect(
        tester.getCenter(find.byKey(RangeSelectionOverlay.startHandleKey)).dx,
        closeTo(plotLeft + plotWidth * 0.25, 0.001),
      );
      expect(
        tester.getCenter(find.byKey(RangeSelectionOverlay.endHandleKey)).dx,
        closeTo(plotLeft + plotWidth * 0.75, 0.001),
      );
    });

    testWidgets('spans the plot rect vertically, not the whole chart', (
      tester,
    ) async {
      await pumpOverlay(tester);

      final rect = tester.getRect(
        find.byKey(RangeSelectionOverlay.startHandleKey),
      );
      expect(rect.top, closeTo(0, 0.001));
      expect(rect.bottom, closeTo(204, 0.001));
    });

    testWidgets('follows the visible window when the chart is zoomed', (
      tester,
    ) async {
      await pumpOverlay(
        tester,
        visibleMinSeconds: 1800,
        visibleMaxSeconds: 3600,
      );

      // Start (900 s) has scrolled off the left of the window.
      expect(find.byKey(RangeSelectionOverlay.startHandleKey), findsNothing);
      expect(
        tester.getCenter(find.byKey(RangeSelectionOverlay.endHandleKey)).dx,
        closeTo(plotLeft + plotWidth * 0.5, 0.001),
      );
    });
  });

  group('dragging', () {
    testWidgets('reports the dragged start in seconds', (tester) async {
      final changes = <(int, int)>[];
      await pumpOverlay(
        tester,
        onRangeChanged: (start, end) => changes.add((start, end)),
      );

      // A quarter of the plot rect is a quarter of the 3600 s window.
      await tester.drag(
        find.byKey(RangeSelectionOverlay.startHandleKey),
        const Offset(plotWidth * 0.25, 0),
      );
      await tester.pump();

      expect(changes.last.$1, closeTo(1800, 1));
      expect(changes.last.$2, 2700);
    });

    testWidgets('scales the drag by the visible window when zoomed', (
      tester,
    ) async {
      final changes = <(int, int)>[];
      await pumpOverlay(
        tester,
        visibleMinSeconds: 1800,
        visibleMaxSeconds: 3600,
        onRangeChanged: (start, end) => changes.add((start, end)),
      );

      // Half the plot rect is 900 s at 2x zoom, not 1800 s.
      await tester.drag(
        find.byKey(RangeSelectionOverlay.endHandleKey),
        const Offset(plotWidth * 0.5, 0),
      );
      await tester.pump();

      expect(changes.last.$2, closeTo(3600, 1));
    });

    testWidgets('keeps the start handle behind the end handle', (tester) async {
      final changes = <(int, int)>[];
      await pumpOverlay(
        tester,
        onRangeChanged: (start, end) => changes.add((start, end)),
      );

      await tester.drag(
        find.byKey(RangeSelectionOverlay.startHandleKey),
        const Offset(plotWidth, 0),
      );
      await tester.pump();

      expect(changes.last.$1, 2699);
    });

    testWidgets('releases the chart when range mode ends mid-drag', (
      tester,
    ) async {
      final active = <bool>[];
      await pumpOverlay(tester, onDragActiveChanged: active.add);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(RangeSelectionOverlay.endHandleKey)),
      );
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(active, [true]);

      // Range mode is switched off while the finger is still down.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox(width: 400))),
      );
      await gesture.up();

      expect(active, [true, false]);
    });

    testWidgets('announces drag start and end so the chart can stop panning', (
      tester,
    ) async {
      final active = <bool>[];
      await pumpOverlay(tester, onDragActiveChanged: active.add);

      await tester.drag(
        find.byKey(RangeSelectionOverlay.endHandleKey),
        const Offset(10, 0),
      );
      await tester.pump();

      expect(active, [true, false]);
    });
  });

  testWidgets('shades only the plot rect outside the selection', (
    tester,
  ) async {
    await pumpOverlay(tester);

    final before = tester.getRect(
      find.byKey(RangeSelectionOverlay.leadingShadeKey),
    );
    final after = tester.getRect(
      find.byKey(RangeSelectionOverlay.trailingShadeKey),
    );
    expect(before.left, closeTo(plotLeft, 0.001));
    expect(before.right, closeTo(plotLeft + plotWidth * 0.25, 0.001));
    expect(before.bottom, closeTo(204, 0.001));
    expect(after.left, closeTo(plotLeft + plotWidth * 0.75, 0.001));
    expect(after.right, closeTo(plotLeft + plotWidth, 0.001));
  });
}
