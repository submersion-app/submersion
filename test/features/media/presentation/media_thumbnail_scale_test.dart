import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_row_height_builder.dart';

/// The middle stop's row height across a pane [width] wide.
double _middle(double width) => 64 * math.sqrt(width / 2 / 64);

void main() {
  group('thumbnail steps (issues #3297, #4738)', () {
    test('there are seven, and the gallery opens on the middle one', () {
      expect(kMediaThumbnailSteps, 7);
      expect(const MediaThumbnailScale().step, 3);
      expect(const MediaThumbnailScale().rowHeight, isNull);
    });

    test('rows run from 64 to half the pane in equal ratios', () {
      expect(mediaThumbnailRowHeightForStep(0, 1200), 64);
      expect(mediaThumbnailRowHeightForStep(6, 1200), moreOrLessEquals(600));
      expect(
        mediaThumbnailRowHeightForStep(3, 1200),
        moreOrLessEquals(_middle(1200)),
      );
    });

    test('a pane too narrow for a 64 row at half its width gives 64', () {
      for (var step = 0; step < kMediaThumbnailSteps; step++) {
        expect(mediaThumbnailRowHeightForStep(step, 100), 64);
      }
    });
  });

  group('spacing', () {
    test('a phone-width pane packs tighter', () {
      expect(mediaThumbnailGap(599), 2);
      expect(mediaThumbnailGap(600), 4);
      expect(mediaThumbnailInset(599), 2);
      expect(mediaThumbnailInset(600), 8);
    });
  });

  group('mediaThumbnailDecodeTarget', () {
    test('the longest side picks one of three sizes', () {
      expect(
        mediaThumbnailDecodeTarget(const Size(150, 200)),
        const Size.square(200),
      );
      expect(
        mediaThumbnailDecodeTarget(const Size(300, 201)),
        const Size.square(400),
      );
      expect(
        mediaThumbnailDecodeTarget(const Size(900, 300)),
        const Size.square(800),
      );
    });
  });

  group('MediaThumbnailScale.rowHeightAt', () {
    test('before anything is held, follows the step at that width', () {
      const scale = MediaThumbnailScale();
      expect(scale.rowHeightAt(1200), moreOrLessEquals(_middle(1200)));
      expect(scale.rowHeightAt(800), moreOrLessEquals(_middle(800)));
    });

    test('a held height stays when the pane is resized', () {
      const scale = MediaThumbnailScale(rowHeight: 180);
      expect(scale.rowHeightAt(1200), 180);
      expect(scale.rowHeightAt(2000), 180);
    });

    test('but never goes past half the pane', () {
      const scale = MediaThumbnailScale(rowHeight: 500);
      expect(scale.rowHeightAt(800), 400);
    });
  });

  group('mediaThumbnailScaleProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('choosing a step drops the held height, to be re-read at the '
        'current width', () {
      final notifier = container.read(mediaThumbnailScaleProvider.notifier);
      notifier.hold(180);
      expect(container.read(mediaThumbnailScaleProvider).rowHeight, 180);

      notifier.setStep(5);

      final scale = container.read(mediaThumbnailScaleProvider);
      expect(scale.step, 5);
      expect(scale.rowHeight, isNull);
    });

    test('a height already held is not replaced', () {
      final notifier = container.read(mediaThumbnailScaleProvider.notifier);
      notifier.hold(180);
      notifier.hold(90);
      expect(container.read(mediaThumbnailScaleProvider).rowHeight, 180);
    });

    test('a step past either end keeps the held height', () {
      final notifier = container.read(mediaThumbnailScaleProvider.notifier);
      notifier.setStep(6);
      notifier.hold(400);
      notifier.stepBy(1);
      expect(container.read(mediaThumbnailScaleProvider).rowHeight, 400);
    });

    test('steps outside the slider are clamped', () {
      final notifier = container.read(mediaThumbnailScaleProvider.notifier);
      notifier.setStep(99);
      expect(container.read(mediaThumbnailScaleProvider).step, 6);
      notifier.setStep(-1);
      expect(container.read(mediaThumbnailScaleProvider).step, 0);
    });
  });

  group('MediaThumbnailRowHeightBuilder', () {
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
            child: MediaThumbnailRowHeightBuilder(
              builder: (context, rowHeight) {
                builds++;
                return Text('rows ${rowHeight.round()}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens on the middle size', (tester) async {
      await pump(tester, 1200);
      expect(find.text('rows ${_middle(1200).round()}'), findsOneWidget);
    });

    testWidgets('holding the height does not build the gallery again', (
      tester,
    ) async {
      await pump(tester, 1200);
      expect(
        container.read(mediaThumbnailScaleProvider).rowHeight,
        moreOrLessEquals(_middle(1200)),
      );
      expect(builds, 1);
    });

    testWidgets('resizing the window keeps the row height', (tester) async {
      await pump(tester, 1200);
      await pump(tester, 800);
      expect(find.text('rows ${_middle(1200).round()}'), findsOneWidget);
    });

    testWidgets('a new step is read at the width it was chosen at, then held', (
      tester,
    ) async {
      await pump(tester, 1200);
      container.read(mediaThumbnailScaleProvider.notifier).setStep(0);
      await tester.pumpAndSettle();
      expect(find.text('rows 64'), findsOneWidget);

      await pump(tester, 1000);
      expect(find.text('rows 64'), findsOneWidget);
    });
  });
}
