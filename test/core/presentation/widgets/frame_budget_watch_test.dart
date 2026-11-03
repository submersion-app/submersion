import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/widgets/frame_budget_watch.dart';

const _fast = Duration(milliseconds: 8);
const _slow = Duration(milliseconds: 120);

void main() {
  test('trips once enough of the recent frames are slow', () {
    final watch = FrameBudgetWatch();

    expect(watch.record(List.filled(5, _slow)), isFalse);
    expect(watch.record([_slow]), isTrue);
    expect(watch.tripped, isTrue);
  });

  test('a few slow frames among fast ones do not trip it', () {
    final watch = FrameBudgetWatch();

    // Startup's first frames (fonts, shaders) can be slow on any device.
    final spans = [...List.filled(3, _slow), ...List.filled(30, _fast)];

    expect(watch.record(spans), isFalse);
    expect(watch.tripped, isFalse);
  });

  test('slow frames that fell out of the window no longer count', () {
    final watch = FrameBudgetWatch();

    watch.record(List.filled(5, _slow));
    watch.record(List.filled(12, _fast));

    expect(watch.record(List.filled(5, _slow)), isFalse);
  });

  test('a frame exactly at the budget is not slow', () {
    final watch = FrameBudgetWatch();

    expect(
      watch.record(List.filled(12, const Duration(milliseconds: 50))),
      isFalse,
    );
  });

  test('stays tripped whatever comes after', () {
    final watch = FrameBudgetWatch();
    watch.record(List.filled(6, _slow));

    expect(watch.record(List.filled(100, _fast)), isTrue);
    expect(watch.tripped, isTrue);
  });
}
