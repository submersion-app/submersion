import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/scenes/scene_clock.dart';

void main() {
  late List<double> published;

  Future<void> pumpClock(
    WidgetTester tester, {
    bool disableAnimations = false,
    bool tickersEnabled = true,
  }) async {
    published = <double>[];
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: TickerMode(
          enabled: tickersEnabled,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SceneClock(
              builder: (context, seconds) {
                published.add(seconds);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pumps one second of 60 Hz frames and counts how many published a new
  /// value.
  Future<int> countChangesOverOneSecond(WidgetTester tester) async {
    var changes = 0;
    var last = published.last;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(microseconds: 16667));
      if (published.last != last) changes++;
      last = published.last;
    }
    return changes;
  }

  testWidgets('does not request a frame on every vsync', (tester) async {
    await pumpClock(tester);

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('advances about 24 times a second', (tester) async {
    await pumpClock(tester);

    expect(await countChangesOverOneSecond(tester), inInclusiveRange(20, 24));
  });

  testWidgets('freezes while the app is not focused and resumes from where '
      'it stopped', (tester) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await pumpClock(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final frozen = published.last;

    expect(await countChangesOverOneSecond(tester), 0);
    expect(published.last, frozen);
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(await countChangesOverOneSecond(tester), greaterThan(0));
    // Resumes from where it froze rather than jumping ahead by the time
    // spent in the background.
    expect(published.last - frozen, lessThan(1.15));
  });

  testWidgets('stops when TickerMode is disabled', (tester) async {
    await pumpClock(tester, tickersEnabled: false);

    expect(await countChangesOverOneSecond(tester), 0);
  });

  testWidgets('holds the still frame under reduce motion', (tester) async {
    await pumpClock(tester, disableAnimations: true);

    expect(published.last, SceneClock.stillSeconds);
    expect(await countChangesOverOneSecond(tester), 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
