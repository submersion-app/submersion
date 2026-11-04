import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/widgets/frame_budget_watch.dart';

const _fast = Duration(milliseconds: 8);
const _slow = Duration(milliseconds: 120);

/// The ocean background's frame interval: 30 frames a second.
const _onTime = Duration(microseconds: 33334);

/// Frames that each take [span], one every [gap], the first starting at
/// [from] (in microseconds).
List<FrameTiming> _frames(
  int count, {
  Duration span = _fast,
  Duration gap = _onTime,
  int from = 0,
}) {
  return [
    for (var i = 0; i < count; i++) _frame(from + i * gap.inMicroseconds, span),
  ];
}

FrameTiming _frame(int vsyncStart, Duration span) {
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

/// Where the next frame after [frames] starts, one [gap] later.
int _after(List<FrameTiming> frames, [Duration gap = _onTime]) =>
    frames.last.timestampInMicroseconds(FramePhase.vsyncStart) +
    gap.inMicroseconds;

void main() {
  group('frames that take too long', () {
    test('trips once enough of the recent frames are slow', () {
      final watch = FrameBudgetWatch();
      final first = _frames(5, span: _slow);

      expect(watch.record(first), isFalse);
      expect(
        watch.record(_frames(1, span: _slow, from: _after(first))),
        isTrue,
      );
      expect(watch.tripped, isTrue);
    });

    test('a few slow frames among fast ones do not trip it', () {
      final watch = FrameBudgetWatch();

      // Startup's first frames (fonts, shaders) can be slow on any device.
      final slow = _frames(3, span: _slow);

      expect(watch.record(slow), isFalse);
      expect(watch.record(_frames(30, from: _after(slow))), isFalse);
      expect(watch.tripped, isFalse);
    });

    test('slow frames that fell out of the window no longer count', () {
      final watch = FrameBudgetWatch();

      final slow = _frames(5, span: _slow);
      watch.record(slow);
      final fast = _frames(12, from: _after(slow));
      watch.record(fast);

      expect(
        watch.record(_frames(5, span: _slow, from: _after(fast))),
        isFalse,
      );
    });

    test('a frame exactly at the budget is not slow', () {
      final watch = FrameBudgetWatch();

      expect(
        watch.record(_frames(12, span: const Duration(milliseconds: 50))),
        isFalse,
      );
    });
  });

  // A browser that draws WebGL in software (Chromium's SwiftShader) does the
  // drawing in its GPU process, after the frame's timings end: each frame
  // looks quick while they arrive about half as often as asked, and the drawing
  // starves the rest of the page (#4186).
  group('frames that arrive late', () {
    test('trips when quick frames keep arriving late', () {
      final watch = FrameBudgetWatch();

      expect(
        watch.record(_frames(13, gap: const Duration(milliseconds: 60))),
        isTrue,
      );
      expect(watch.tripped, isTrue);
    });

    test('an odd window judges by its middle gap', () {
      final watch = FrameBudgetWatch(window: 5);
      const late = Duration(milliseconds: 60);

      // Three gaps on time and two late: the middle one is on time.
      final onTime = _frames(4);
      watch.record(onTime);
      final lateFrames = _frames(2, gap: late, from: _after(onTime, late));
      expect(watch.record(lateFrames), isFalse);

      // One more late gap pushes an on-time one out: now the middle is late.
      expect(watch.record(_frames(1, from: _after(lateFrames, late))), isTrue);
    });

    test('does not judge the pace before the window has filled', () {
      final watch = FrameBudgetWatch();

      expect(
        watch.record(_frames(12, gap: const Duration(milliseconds: 60))),
        isFalse,
      );
    });

    test('frames on time do not trip it', () {
      final watch = FrameBudgetWatch();

      expect(watch.record(_frames(60)), isFalse);
    });

    test('timer jitter on a 60 Hz display does not trip it', () {
      final watch = FrameBudgetWatch();

      // The animation asks for a frame every 33.3 ms, two refreshes of a
      // 60 Hz display; jitter lands some frames a refresh early and the
      // next a refresh late.
      final frames = <FrameTiming>[];
      var at = 0;
      for (var i = 0; i < 40; i++) {
        frames.add(_frame(at, _fast));
        at += i.isEven ? 16667 : 50001;
      }

      expect(watch.record(frames), isFalse);
    });

    test('one long pause does not trip it', () {
      final watch = FrameBudgetWatch();

      final before = _frames(6);
      watch.record(before);
      final after = _frames(
        20,
        from: _after(before, const Duration(milliseconds: 800)),
      );

      expect(watch.record(after), isFalse);
    });

    test('a pause across a restart is not a late frame', () {
      final watch = FrameBudgetWatch();
      const late = Duration(milliseconds: 60);

      final before = _frames(11, gap: late);
      watch.record(before);
      watch.restartCadence();
      // Kept, the ten late gaps before the restart, the pause across it and
      // the late gap after would fill the window and trip it.
      final after = _frames(
        2,
        gap: late,
        from: _after(before, const Duration(seconds: 5)),
      );

      expect(watch.record(after), isFalse);
    });
  });

  test('stays tripped whatever comes after', () {
    final watch = FrameBudgetWatch();
    final slow = _frames(6, span: _slow);
    watch.record(slow);

    expect(watch.record(_frames(100, from: _after(slow))), isTrue);
    expect(watch.tripped, isTrue);
  });
}
