import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/widgets/ocean_background.dart';

const _abyssTop = Color(0xFF0B2540);
const _lightTop = Color(0xFF00ACC1);

Future<void> _pumpBackground(
  WidgetTester tester, {
  Brightness? override,
  required Brightness themeBrightness,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: themeBrightness),
      home: OceanBackground(
        brightness: override,
        child: const SizedBox.expand(),
      ),
    ),
  );
  await tester.pump();
}

LinearGradient _gradientOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(OceanBackground),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return decoration.gradient! as LinearGradient;
}

void main() {
  testWidgets('dark theme renders the Abyss Blue gradient', (tester) async {
    await _pumpBackground(tester, themeBrightness: Brightness.dark);
    final gradient = _gradientOf(tester);
    expect(gradient.colors, [
      _abyssTop,
      const Color(0xFF08243A).withValues(alpha: 0.9),
      const Color(0xFF041220).withValues(alpha: 0.85),
    ]);
  });

  testWidgets('light theme renders the existing teal gradient', (tester) async {
    await _pumpBackground(tester, themeBrightness: Brightness.light);
    final gradient = _gradientOf(tester);
    expect(gradient.colors, [
      _lightTop,
      const Color(0xFF00ACC1).withValues(alpha: 0.9),
      const Color(0xFF009688).withValues(alpha: 0.85),
    ]);
  });

  testWidgets('brightness override beats the ambient theme both ways', (
    tester,
  ) async {
    await _pumpBackground(
      tester,
      override: Brightness.light,
      themeBrightness: Brightness.dark,
    );
    expect(_gradientOf(tester).colors.first, _lightTop);

    await _pumpBackground(
      tester,
      override: Brightness.dark,
      themeBrightness: Brightness.light,
    );
    expect(_gradientOf(tester).colors.first, _abyssTop);
  });

  // The caustic gradients are transparent beyond their radius, so filling
  // more than their squares draws nothing. A browser drawing without WebGL
  // rasterises every picture on every frame, and two full-screen fills made
  // each spinner frame cost 134 ms on the page's thread, which starved
  // drift's replies until setup stalled (#4186).
  test('fills only the squares the caustic shimmer reaches', () {
    const size = Size(1280, 900);
    final painter = OceanEffectPainter(
      animationValue: 0,
      bubbleColor: Colors.white,
      causticOpacity: 0.12,
    );

    // At the start of the cycle each patch sits 4 points off its rest.
    expect(
      (Canvas canvas) => painter.paint(canvas, size),
      paints
        ..rect(
          rect: Rect.fromCircle(
            center: Offset(size.width * 0.3, size.height * 0.4 + 4),
            radius: 80,
          ),
        )
        ..rect(
          rect: Rect.fromCircle(
            center: Offset(size.width * 0.7, size.height * 0.6 - 4),
            radius: 60,
          ),
        ),
    );
  });

  group('frame budget (#3044)', () {
    double animationValueOf(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is OceanEffectPainter,
        ),
      );
      return (paint.painter! as OceanEffectPainter).animationValue;
    }

    Future<void> pumpAnimated(
      WidgetTester tester, {
      bool disableAnimations = false,
      bool tickersEnabled = true,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: TickerMode(
            enabled: tickersEnabled,
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: OceanBackground(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    /// Pumps one second of 60 Hz frames and returns how many of them painted
    /// a new animation value.
    Future<int> countRepaintsOverOneSecond(WidgetTester tester) async {
      var changes = 0;
      var last = animationValueOf(tester);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(microseconds: 16667));
        final value = animationValueOf(tester);
        if (value != last) changes++;
        last = value;
      }
      return changes;
    }

    testWidgets('does not request a frame on every vsync', (tester) async {
      await pumpAnimated(tester);

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('caps the animation at 30 frames per second', (tester) async {
      await pumpAnimated(tester);

      final repaints = await countRepaintsOverOneSecond(tester);

      expect(repaints, inInclusiveRange(25, 30));
    });

    testWidgets('freezes while the app is not focused and resumes after', (
      tester,
    ) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await pumpAnimated(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      final frozen = animationValueOf(tester);

      expect(await countRepaintsOverOneSecond(tester), 0);
      expect(animationValueOf(tester), frozen);
      expect(tester.binding.hasScheduledFrame, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(await countRepaintsOverOneSecond(tester), greaterThan(0));
      // Resumes from where it froze rather than jumping ahead by the time
      // spent in the background.
      expect(animationValueOf(tester) - frozen, lessThan(0.15));
    });

    testWidgets('paints a still frame when reduce motion is on', (
      tester,
    ) async {
      await pumpAnimated(tester, disableAnimations: true);

      expect(find.byType(CustomPaint), findsWidgets);
      expect(await countRepaintsOverOneSecond(tester), 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    FrameTiming frameTaking(Duration span, {int vsyncStart = 0}) {
      final micros = span.inMicroseconds;
      return FrameTiming(
        vsyncStart: vsyncStart,
        buildStart: vsyncStart,
        buildFinish: vsyncStart + micros ~/ 2,
        rasterStart: vsyncStart + micros ~/ 2,
        rasterFinish: vsyncStart + micros,
        rasterFinishWallTime: vsyncStart + micros,
      );
    }

    void reportFrames(WidgetTester tester, Duration span, int count) {
      tester.binding.platformDispatcher.onReportTimings!(
        List.filled(count, frameTaking(span)),
      );
    }

    // A browser without WebGL renders on the CPU, where each repaint costs
    // more than the animation's frame interval; the bubbles then starved
    // startup of the main thread and the splash never moved on (#4177).
    testWidgets('holds still once its frames keep running over budget', (
      tester,
    ) async {
      await pumpAnimated(tester);

      reportFrames(tester, const Duration(milliseconds: 120), 12);
      await tester.pump();

      expect(await countRepaintsOverOneSecond(tester), 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    // Chromium drawing WebGL in software does the drawing in its GPU process,
    // after a frame's timings end: each frame looks quick, they arrive about
    // half as often as asked, and the drawing starved drift's workers while
    // the splash waited on the database (#4186).
    testWidgets('holds still once its frames keep arriving late', (
      tester,
    ) async {
      await pumpAnimated(tester);

      tester.binding.platformDispatcher.onReportTimings!([
        for (var i = 0; i < 13; i++)
          frameTaking(const Duration(milliseconds: 8), vsyncStart: i * 60000),
      ]);
      await tester.pump();

      expect(await countRepaintsOverOneSecond(tester), 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('keeps animating through a few slow frames', (tester) async {
      await pumpAnimated(tester);

      reportFrames(tester, const Duration(milliseconds: 120), 3);
      reportFrames(tester, const Duration(milliseconds: 8), 20);
      await tester.pump();

      expect(await countRepaintsOverOneSecond(tester), greaterThan(0));
    });

    testWidgets('stays still while its route has tickers disabled', (
      tester,
    ) async {
      await pumpAnimated(tester, tickersEnabled: false);

      expect(await countRepaintsOverOneSecond(tester), 0);

      await pumpAnimated(tester);

      expect(await countRepaintsOverOneSecond(tester), greaterThan(0));
    });
  });
}
