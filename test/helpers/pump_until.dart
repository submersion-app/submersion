import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until [condition] returns true, then returns.
///
/// The widget-test analogue of `waitUntil`: inside `testWidgets` the clock is
/// fake, so a real `Future.delayed` never advances and a fixed-duration pump
/// hard-codes an assumption about how many frames the work takes. Polling the
/// condition states that assumption instead of guessing at it.
///
/// Fails the test if [condition] is still false after [maxFrames], so a state
/// that is never reached surfaces as an explicit failure rather than an
/// assertion that passes for the wrong reason.
///
/// [maxFrames] must be at least 1: one frame is always pumped, so a smaller
/// budget could not be honoured.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxFrames = 100,
  Duration interval = const Duration(milliseconds: 10),
  String? reason,
}) async {
  assert(
    maxFrames >= 1,
    'pumpUntil always pumps one frame; maxFrames must be >= 1',
  );
  // Always pump at least one frame before believing [condition]. A provider
  // state such as `isReloading` becomes true the instant the reload is
  // scheduled, before the widgets that read it have rebuilt: returning then
  // would leave the caller asserting on props left over from the previous
  // frame, which passes whatever the widget does with the new state.
  await tester.pump(interval);
  for (var frame = 1; frame < maxFrames && !condition(); frame++) {
    await tester.pump(interval);
  }
  if (!condition()) {
    fail(
      'pumpUntil: condition not met within $maxFrames frames'
      '${reason == null ? '' : ' ($reason)'}',
    );
  }
}

/// [pumpUntil] for work that does real IO, such as a file read or the first
/// native SQLite open in the isolate: fake-clock frames never let that IO
/// finish, and a single fixed `runAsync` delay guesses at how long it takes
/// (the first SQLite open can outlast 50 ms on a cold isolate). Each round
/// yields [interval] of real time inside `runAsync`, then pumps a frame.
///
/// Fails the test if [condition] is still false after [maxRounds].
Future<void> pumpUntilRealAsync(
  WidgetTester tester,
  bool Function() condition, {
  int maxRounds = 100,
  Duration interval = const Duration(milliseconds: 20),
  String? reason,
}) async {
  for (var round = 0; round < maxRounds && !condition(); round++) {
    await tester.runAsync(() => Future<void>.delayed(interval));
    await tester.pump();
  }
  if (!condition()) {
    fail(
      'pumpUntilRealAsync: condition not met within $maxRounds rounds'
      '${reason == null ? '' : ' ($reason)'}',
    );
  }
}
