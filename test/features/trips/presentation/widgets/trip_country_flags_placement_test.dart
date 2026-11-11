import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_country.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/compact_trip_list_tile.dart';
import 'package:submersion/features/trips/presentation/widgets/dense_trip_list_tile.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_country_flags.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_list_content.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Every trip list density shows a trip's flags after its name, at most
/// three then "+N" (issue #4426).
void main() {
  final trip = TripWithStats(
    trip: Trip(
      id: 't1',
      name: 'Central America',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 14),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    diveCount: 20,
  );

  Future<void> pumpTile(WidgetTester tester, Widget tile) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tripCountriesProvider.overrideWith(
            (ref) async => {
              't1': const [
                TripCountry(code: 'MX', name: 'Mexico'),
                TripCountry(code: 'BZ', name: 'Belize'),
                TripCountry(code: 'HN', name: 'Honduras'),
                TripCountry(code: 'GT', name: 'Guatemala'),
              ],
            },
          ),
        ],
        child: tile,
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectThreeFlagsAndMore(WidgetTester tester) {
    final flags = tester.widget<TripCountryFlags>(
      find.byType(TripCountryFlags),
    );
    expect(flags.tripId, 't1');
    expect(flags.maxFlags, 3);
    expect(find.byType(CountryFlag), findsNWidgets(3));
    expect(find.text('+1'), findsOneWidget);
  }

  testWidgets('detailed tile', (tester) async {
    await pumpTile(tester, TripListTile(tripWithStats: trip, onTap: () {}));
    expectThreeFlagsAndMore(tester);
  });

  testWidgets('compact tile', (tester) async {
    await pumpTile(
      tester,
      CompactTripListTile(tripWithStats: trip, onTap: () {}),
    );
    expectThreeFlagsAndMore(tester);
  });

  testWidgets('dense tile', (tester) async {
    await pumpTile(
      tester,
      DenseTripListTile(tripWithStats: trip, onTap: () {}),
    );
    expectThreeFlagsAndMore(tester);
  });

  testWidgets('a long trip name still fits beside the flags', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longTrip = TripWithStats(
      trip: trip.trip.copyWith(
        name: 'Kingston and the Thousand Islands with a very long name 2026',
      ),
    );
    await pumpTile(
      tester,
      DenseTripListTile(tripWithStats: longTrip, onTap: () {}),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(CountryFlag), findsNWidgets(3));
  });

  testWidgets('a wrapped name keeps its flags beside its last word', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const name = 'Kingston and the Thousand Islands with a very long name 2026';
    final longTrip = TripWithStats(trip: trip.trip.copyWith(name: name));
    await pumpTile(tester, TripListTile(tripWithStats: longTrip, onTap: () {}));

    final titleFinder = find.text(name);
    final title = tester.getRect(titleFinder);
    final flags = tester.getRect(find.byType(TripCountryFlags));
    expect(title.height, greaterThan(30)); // the name wraps
    // Beside the text, not on a line of its own below it...
    expect(flags.center.dy, lessThan(title.bottom));
    expect(flags.center.dy, greaterThan(title.top));
    // ...and right after its longest line, not out at the row's far edge:
    // the name's box shrinks to that line.
    expect(
      tester.widget<Text>(titleFinder).textWidthBasis,
      TextWidthBasis.longestLine,
    );
    expect(flags.left - title.right, lessThan(10));
  });

  testWidgets('a name that fits keeps its flag on the same line', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const name = 'Santa Marta and Taganga 2026';
    final fitting = TripWithStats(trip: trip.trip.copyWith(name: name));
    await pumpTile(tester, TripListTile(tripWithStats: fitting, onTap: () {}));

    final title = tester.getRect(find.text(name));
    final flags = tester.getRect(find.byType(TripCountryFlags));
    expect(flags.center.dy, lessThan(title.bottom));
  });
}
