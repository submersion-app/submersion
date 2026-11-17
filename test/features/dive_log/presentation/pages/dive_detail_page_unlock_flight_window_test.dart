import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';

import 'dive_detail_page_unlock_harness.dart';

/// The trip's flight warning, pinned under the edit bar while the dive is
/// unlocked, as the old edit form pinned it above its fields (issue #4527,
/// plan 11): editing a dive that ends after the latest safe surfacing time
/// for the trip's flight warns, and never blocks.
void main() {
  // 15:00 local on the day: the latest safe surfacing time.
  final status = FlightWindowStatus(
    state: FlightWindowState.open,
    flightAt: DateTime(2126, 8, 10, 9).toUtc(),
    deadline: DateTime(2126, 8, 9, 15).toUtc(),
    category: NoFlyCategory.repetitive,
    interval: const Duration(hours: 18),
  );

  // Clock digits, as a dive's times are kept: it ends at 16:00.
  final late = dive.copyWith(
    tripId: 't1',
    dateTime: DateTime.utc(2126, 8, 9, 15, 10),
    entryTime: DateTime.utc(2126, 8, 9, 15, 10),
    exitTime: DateTime.utc(2126, 8, 9, 16),
  );

  final extra = [tripFlightWindowProvider('t1').overrideWith((_) => status)];

  Finder warning() =>
      find.textContaining('after the latest safe surfacing time');

  for (final embedded in [false, true]) {
    final where = embedded ? 'in the pane' : 'on the full page';

    testWidgets('$where: locked, no warning; unlocked, the warning shows', (
      tester,
    ) async {
      await pumpPage(tester, stored: late, embedded: embedded, extra: extra);
      await settle(tester);
      expect(warning(), findsNothing);

      await unlock(tester);
      expect(warning(), findsOneWidget);
    });
  }

  testWidgets('a dive that ends before the deadline shows no warning', (
    tester,
  ) async {
    await pumpPage(
      tester,
      stored: late.copyWith(exitTime: DateTime.utc(2126, 8, 9, 14)),
      extra: extra,
    );
    await settle(tester);
    await unlock(tester);
    expect(warning(), findsNothing);
  });
}
