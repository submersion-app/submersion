import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_columns_builder.dart';

void main() {
  group('thumbnail steps (issue #3297)', () {
    test('there are seven, and the gallery opens on the middle one', () {
      expect(kMediaThumbnailSteps, 7);
      expect(const MediaThumbnailScale().step, 3);
      expect(const MediaThumbnailScale().columns, isNull);
    });

    test('the largest step is half the pane, at any width', () {
      for (final width in [200.0, 360.0, 800.0, 1200.0, 2400.0]) {
        expect(mediaThumbnailColumnsForStep(6, width), 2, reason: '$width');
      }
    });

    test('the smallest step is as many as fit at 64 or more', () {
      // The grouped list's 16 of padding and the 4 between tiles come off
      // first: 17 across 1200 is (1184 - 16 x 4) / 17 = 65.9 each, and an
      // eighteenth column would drop them to 62.0.
      expect(mediaThumbnailColumnsForStep(0, 1200), 17);
      expect(mediaThumbnailColumnsForStep(0, 800), 11);
      expect(mediaThumbnailColumnsForStep(0, 352), 5);
    });

    test('no step draws a tile under 64 once gaps and padding are '
        'taken off', () {
      // From the narrowest pane that holds two 64px tiles at all.
      for (var width = 148.0; width <= 3000; width += 7) {
        for (var step = 0; step < kMediaThumbnailSteps; step++) {
          final columns = mediaThumbnailColumnsForStep(step, width);
          // The grouped list, whose 8 a side is the widest padding.
          final tile =
              (width -
                  kMediaThumbnailMaxInset -
                  (columns - 1) * kMediaThumbnailGap) /
              columns;
          expect(
            tile,
            greaterThanOrEqualTo(kMediaThumbnailMinExtent),
            reason: 'step $step at $width: $columns across',
          );
        }
      }
    });

    test('a desktop pane gets seven different sizes, smallest first', () {
      final columns = [
        for (var step = 0; step < kMediaThumbnailSteps; step++)
          mediaThumbnailColumnsForStep(step, 1200),
      ];
      expect(columns, [17, 13, 9, 6, 4, 3, 2]);
    });

    test('a pane too narrow for two 64px tiles still shows two', () {
      expect(mediaThumbnailColumnsForStep(0, 100), 2);
      expect(mediaThumbnailColumnsForStep(3, 100), 2);
    });
  });

  group('MediaThumbnailScale.columnsAt', () {
    test('before anything is held, follows the step at that width', () {
      const scale = MediaThumbnailScale();
      expect(scale.columnsAt(1200), 6);
      expect(scale.columnsAt(800), 5);
    });

    test('a held count stays the same when the pane is resized', () {
      const scale = MediaThumbnailScale(columns: 6);
      expect(scale.columnsAt(1200), 6);
      expect(scale.columnsAt(800), 6);
      expect(scale.columnsAt(2000), 6);
    });

    test('but never squeezes tiles below 64', () {
      const scale = MediaThumbnailScale(columns: 6);
      expect(scale.columnsAt(300), 4);
    });
  });

  group('mediaThumbnailScaleProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('choosing a step drops the held count, to be re-read at the '
        'current width', () {
      final notifier = container.read(mediaThumbnailScaleProvider.notifier);
      notifier.hold(6);
      expect(container.read(mediaThumbnailScaleProvider).columns, 6);

      notifier.setStep(5);

      final scale = container.read(mediaThumbnailScaleProvider);
      expect(scale.step, 5);
      expect(scale.columns, isNull);
    });

    test('a count already held is not replaced', () {
      final notifier = container.read(mediaThumbnailScaleProvider.notifier);
      notifier.hold(6);
      notifier.hold(9);
      expect(container.read(mediaThumbnailScaleProvider).columns, 6);
    });

    test('steps outside the slider are clamped', () {
      final notifier = container.read(mediaThumbnailScaleProvider.notifier);
      notifier.setStep(99);
      expect(container.read(mediaThumbnailScaleProvider).step, 6);
      notifier.setStep(-1);
      expect(container.read(mediaThumbnailScaleProvider).step, 0);
    });
  });

  group('MediaThumbnailColumnsBuilder', () {
    late ProviderContainer container;
    late int builds;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      builds = 0;
    });

    Future<void> pump(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaThumbnailColumnsBuilder(
              builder: (context, columns, targetSize) {
                builds++;
                return Text('$columns across at ${targetSize.width.toInt()}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens on the middle size', (tester) async {
      await pump(tester, 1200);
      expect(find.textContaining('6 across at'), findsOneWidget);
    });

    testWidgets('hands over the decode size for the width and count', (
      tester,
    ) async {
      await pump(tester, 1200);
      // 1200 / 6 is 200 a thumbnail.
      expect(find.text('6 across at 200'), findsOneWidget);

      container.read(mediaThumbnailScaleProvider.notifier).setStep(6);
      await tester.pumpAndSettle();
      // 1200 / 2 is 600, past 400.
      expect(find.text('2 across at 800'), findsOneWidget);
    });

    testWidgets('holding the count does not build the gallery again', (
      tester,
    ) async {
      await pump(tester, 1200);
      expect(container.read(mediaThumbnailScaleProvider).columns, 6);
      expect(builds, 1);
    });

    testWidgets('resizing the window keeps the same number across', (
      tester,
    ) async {
      await pump(tester, 1200);
      expect(find.textContaining('6 across at'), findsOneWidget);

      // Unheld, the middle step at 800 would be 5.
      await pump(tester, 800);
      expect(find.textContaining('6 across at'), findsOneWidget);

      await pump(tester, 1600);
      expect(find.textContaining('6 across at'), findsOneWidget);
    });

    testWidgets('a new step is read at the width it was chosen at, then held', (
      tester,
    ) async {
      await pump(tester, 1200);
      container.read(mediaThumbnailScaleProvider.notifier).setStep(1);
      await tester.pumpAndSettle();
      expect(find.textContaining('13 across at'), findsOneWidget);

      await pump(tester, 1000);
      expect(find.textContaining('13 across at'), findsOneWidget);
    });

    testWidgets('the size survives the gallery being closed and reopened', (
      tester,
    ) async {
      await pump(tester, 1200);
      container.read(mediaThumbnailScaleProvider.notifier).setStep(6);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, 1200);

      expect(find.textContaining('2 across at'), findsOneWidget);
      expect(container.read(mediaThumbnailScaleProvider).step, 6);
    });
  });
}
