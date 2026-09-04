import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/compact_trip_list_tile.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_list_content.dart';

import '../../../../helpers/test_app.dart';

/// #1512: the trip tiles dated every row with `DateFormat.yMMMd()`, so a diver
/// on D MMM YYYY still read "Jun 1, 2025".
///
/// Every host pins `Locale('en')`. UnitFormatter's patterns spell the month
/// with `MMM`, which intl resolves against `Intl.defaultLocale` (set from the
/// app locale), so an unpinned host would translate "Jun" on a non-English
/// machine.

/// The tiles watch [settingsProvider]; the real notifier reaches for the
/// database, so stand in with a fixed [AppSettings].
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// `Override` is sealed and not re-exported, so the helper stays dynamic,
// matching `testApp`'s `overrides` parameter.
List<dynamic> _overridesFor(DateFormatPreference format) => [
  settingsProvider.overrideWith(
    (ref) => _TestSettingsNotifier(AppSettings(dateFormat: format)),
  ),
];

TripWithStats _trip() {
  final start = DateTime(2025, 6, 1);
  return TripWithStats(
    trip: Trip(
      id: 'trip-1',
      name: 'Red Sea Explorer',
      startDate: start,
      endDate: DateTime(2025, 6, 8),
      tripType: TripType.shore,
      createdAt: start,
      updatedAt: start,
    ),
    diveCount: 3,
  );
}

void main() {
  group('trip tiles honour the diver date format', () {
    testWidgets('CompactTripListTile prints the day-first range', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: _overridesFor(DateFormatPreference.ddmmyyyy),
          child: CompactTripListTile(tripWithStats: _trip()),
        ),
      );

      expect(find.text('01/06/2025 - 08/06/2025'), findsOneWidget);
    });

    testWidgets('CompactTripListTile prints the spelled month-first range', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: _overridesFor(DateFormatPreference.mmmDYYYY),
          child: CompactTripListTile(tripWithStats: _trip()),
        ),
      );

      expect(find.text('Jun 1, 2025 - Jun 8, 2025'), findsOneWidget);
    });

    testWidgets('TripListTile speaks the range in the diver order', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: _overridesFor(DateFormatPreference.dMMMYYYY),
          child: TripListTile(tripWithStats: _trip()),
        ),
      );

      final label = tester.getSemantics(find.byType(TripListTile)).label;
      expect(label, contains('1 Jun 2025 - 8 Jun 2025'));
      handle.dispose();
    });
  });
}
