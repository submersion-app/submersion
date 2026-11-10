import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/dive_mark_actions.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';

/// "Entered water" and "Surfaced" from the lock screen (issue #637): the
/// tap's time is taken when the tap arrives, not when the app gets round to
/// it, and the notification offers only the next step.
void main() {
  test('only the two action ids map to an action', () {
    expect(diveMarkActionFor('enteredWater'), DiveMarkAction.enteredWater);
    expect(diveMarkActionFor('surfaced'), DiveMarkAction.surfaced);
    expect(diveMarkActionFor('snooze'), isNull);
    expect(diveMarkActionFor(null), isNull);
  });

  test('a tap keeps the time it arrived, even before anyone listens', () async {
    var now = DateTime(2026, 7, 17, 10, 2);
    final actions = DiveMarkActions(clock: () => now);

    expect(actions.handle('enteredWater'), isTrue);
    now = DateTime(2026, 7, 17, 10, 30);
    final tap = await actions.taps.first;

    expect(tap.action, DiveMarkAction.enteredWater);
    expect(tap.at, asWallClockUtc(DateTime(2026, 7, 17, 10, 2)));
  });

  test('a tap with a listener goes straight through', () async {
    final actions = DiveMarkActions(clock: () => DateTime(2026, 7, 17, 11));
    final next = actions.taps.first;

    actions.handle('surfaced');

    expect((await next).action, DiveMarkAction.surfaced);
  });

  test('an unrelated response is left to the other handlers', () {
    expect(DiveMarkActions().handle(null), isFalse);
    expect(DiveMarkActions().handle('other'), isFalse);
  });

  test('the notification offers only the next step', () {
    expect(nextDiveMarkAction(draftOpen: false), DiveMarkAction.enteredWater);
    expect(nextDiveMarkAction(draftOpen: true), DiveMarkAction.surfaced);

    final details = diveMarkNotificationDetails(
      action: DiveMarkAction.surfaced,
      actionLabel: 'Surfaced',
    );
    expect(details.android!.actions!.map((a) => a.id), ['surfaced']);
    expect(details.iOS!.categoryIdentifier, kDiveMarkSurfaceCategory);
  });

  test('tapping the notification itself opens the GPS log', () {
    expect(notificationPayloadRoute(kDiveMarkPayload), '/tracks');
  });
}
