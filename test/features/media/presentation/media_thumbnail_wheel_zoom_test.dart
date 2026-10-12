import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';

void main() {
  late ProviderContainer container;
  late ScrollPosition scroll;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  int step() => container.read(mediaThumbnailScaleProvider).step;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: MediaThumbnailWheelZoom(
              // No controller, as the gallery builds its lists: that is
              // what makes a scroll view default to always-scrollable
              // physics, which take the wheel unless told otherwise.
              child: ListView.builder(
                physics: const MediaThumbnailWheelZoomPhysics(),
                itemCount: 200,
                itemBuilder: (context, index) =>
                    SizedBox(height: 50, child: Text('row $index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll = tester.state<ScrollableState>(find.byType(Scrollable)).position;
  }

  /// One click of the wheel over the list: negative [dy] is wheel up.
  Future<void> wheel(WidgetTester tester, double dy) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(ListView)));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
    await tester.pumpAndSettle();
  }

  Future<void> holding(
    WidgetTester tester,
    LogicalKeyboardKey key,
    Future<void> Function() body,
  ) async {
    await tester.sendKeyDownEvent(key);
    await body();
    await tester.sendKeyUpEvent(key);
  }

  const ctrl = LogicalKeyboardKey.controlLeft;
  const cmd = LogicalKeyboardKey.metaLeft;
  final notMac = TargetPlatformVariant(
    TargetPlatform.values.where((p) => p != TargetPlatform.macOS).toSet(),
  );
  final macOnly = TargetPlatformVariant.only(TargetPlatform.macOS);

  group('Ctrl + wheel (issue #3297)', () {
    testWidgets('wheel up makes thumbnails one notch larger per click', (
      tester,
    ) async {
      await pump(tester);
      expect(step(), 3);

      await holding(tester, ctrl, () async {
        await wheel(tester, -100);
        expect(step(), 4);
        await wheel(tester, -100);
        expect(step(), 5);
      });
    }, variant: notMac);

    testWidgets('wheel down makes them one notch smaller per click', (
      tester,
    ) async {
      await pump(tester);

      await holding(tester, ctrl, () async {
        await wheel(tester, 100);
        expect(step(), 2);
        await wheel(tester, 100);
        expect(step(), 1);
      });
    }, variant: notMac);

    testWidgets('a click is one notch however far the wheel reports', (
      tester,
    ) async {
      await pump(tester);

      await holding(tester, ctrl, () async {
        await wheel(tester, -12);
        expect(step(), 4);
        await wheel(tester, 480);
        expect(step(), 3);
      });
    }, variant: notMac);

    testWidgets('stops at the largest and the smallest size', (tester) async {
      await pump(tester);

      await holding(tester, ctrl, () async {
        for (var i = 0; i < 10; i++) {
          await wheel(tester, -100);
        }
        expect(step(), kMediaThumbnailSteps - 1);
        for (var i = 0; i < 10; i++) {
          await wheel(tester, 100);
        }
        expect(step(), 0);
      });
    }, variant: notMac);

    testWidgets('does not scroll the thumbnails while it resizes them', (
      tester,
    ) async {
      await pump(tester);

      await holding(tester, ctrl, () => wheel(tester, 100));

      expect(scroll.pixels, 0);
      expect(step(), 2);
    }, variant: notMac);

    testWidgets('the wheel alone still scrolls and leaves the size alone', (
      tester,
    ) async {
      await pump(tester);

      await wheel(tester, 100);

      expect(scroll.pixels, 100);
      expect(step(), 3);

      // And again once the modifier has been pressed and let go.
      final modifier = defaultTargetPlatform == TargetPlatform.macOS
          ? cmd
          : ctrl;
      await holding(tester, modifier, () => wheel(tester, 100));
      await wheel(tester, 100);
      expect(scroll.pixels, 200);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Cmd is not the modifier off the Mac', (tester) async {
      await pump(tester);

      await holding(tester, cmd, () => wheel(tester, -100));

      expect(step(), 3);
    }, variant: notMac);
  });

  group('Cmd + wheel on macOS', () {
    testWidgets('resizes, one notch per click, without scrolling', (
      tester,
    ) async {
      await pump(tester);

      await holding(tester, cmd, () async {
        await wheel(tester, -100);
        expect(step(), 4);
        await wheel(tester, 100);
        await wheel(tester, 100);
        expect(step(), 2);
      });
      expect(scroll.pixels, 0);
    }, variant: macOnly);

    // Only the mouse wheel resizes: a trackpad's scroll is not a series of
    // clicks, and one notch per event would race through every size.
    testWidgets('a trackpad scroll event leaves the size alone', (
      tester,
    ) async {
      await pump(tester);

      await holding(tester, cmd, () async {
        final trackpad = TestPointer(1, PointerDeviceKind.trackpad);
        trackpad.hover(tester.getCenter(find.byType(ListView)));
        await tester.sendEventToBinding(trackpad.scroll(const Offset(0, -40)));
        await tester.pumpAndSettle();
      });

      expect(step(), 3);
    }, variant: macOnly);

    // macOS keeps Ctrl + scroll for its own accessibility screen zoom.
    testWidgets('Ctrl is left to the system: it scrolls as usual', (
      tester,
    ) async {
      await pump(tester);

      await holding(tester, ctrl, () => wheel(tester, 100));

      expect(step(), 3);
      expect(scroll.pixels, 100);
    }, variant: macOnly);
  });

  test('stepBy keeps a held count when the step cannot move', () {
    final notifier = container.read(mediaThumbnailScaleProvider.notifier);
    notifier.setStep(kMediaThumbnailSteps - 1);
    notifier.hold(2);

    notifier.stepBy(1);

    final scale = container.read(mediaThumbnailScaleProvider);
    expect(scale.step, kMediaThumbnailSteps - 1);
    expect(scale.columns, 2);
  });
}
