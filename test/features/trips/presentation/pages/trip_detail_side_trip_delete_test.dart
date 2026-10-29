import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/side_trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _MockTripListNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSideTrips extends SideTripRepository {
  _FakeSideTrips(this.sideTrips, this.parent);
  final List<Trip> sideTrips;
  final Trip? parent;

  @override
  Future<List<Trip>> getSideTrips(String tripId, {String? diverId}) async =>
      sideTrips;

  @override
  Future<Trip?> getParentTrip(String tripId, {String? diverId}) async => parent;
}

/// The trip page for a side trip names its larger trip, and the delete
/// confirmation says what happens to side trips and dives (issue #3658).
void main() {
  Trip trip(String id, String name, {String? parent}) => Trip(
    id: id,
    name: name,
    startDate: DateTime(2024, 1, 15),
    endDate: DateTime(2024, 1, 22),
    parentTripId: parent,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  final indonesia = trip('p', 'Indonesia');
  final rajaAmpat = trip('s', 'Raja Ampat', parent: 'p');

  Future<void> pumpTrip(
    WidgetTester tester,
    Trip shown, {
    List<Trip> sideTrips = const [],
    Trip? parent,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((_) async => null),
          allDiversProvider.overrideWith((ref) async => const []),
          tripWithStatsProvider(
            shown.id,
          ).overrideWith((ref) async => TripWithStats(trip: shown)),
          diveIdsForTripProvider(
            shown.id,
          ).overrideWith((ref) async => <String>[]),
          tripListNotifierProvider.overrideWith(
            (ref) => _MockTripListNotifier(),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          sideTripsProvider(shown.id).overrideWith((ref) async => sideTrips),
          parentTripProvider(shown.id).overrideWith((ref) async => parent),
          sideTripRepositoryProvider.overrideWithValue(
            _FakeSideTrips(sideTrips, parent),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripDetailPage(tripId: shown.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDelete(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
  }

  testWidgets('a side trip page names its larger trip', (tester) async {
    await pumpTrip(tester, rajaAmpat, parent: indonesia);
    expect(find.text('Part of Indonesia'), findsOneWidget);
  });

  testWidgets('deleting a larger trip warns its side trip stays', (
    tester,
  ) async {
    await pumpTrip(tester, indonesia, sideTrips: [rajaAmpat]);
    await openDelete(tester);
    expect(
      find.textContaining('Its side trip becomes a trip of its own.'),
      findsOneWidget,
    );
  });

  testWidgets('deleting a side trip says where its dives go', (tester) async {
    await pumpTrip(tester, rajaAmpat, parent: indonesia);
    await openDelete(tester);
    expect(
      find.textContaining('Its dives go back to Indonesia.'),
      findsOneWidget,
    );
  });
}
