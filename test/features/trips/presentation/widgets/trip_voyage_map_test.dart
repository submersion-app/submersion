import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_voyage_map.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _now = DateTime.now();

LiveaboardDetails _makeDetails(String tripId) {
  return LiveaboardDetails(
    id: 'lad-1',
    tripId: tripId,
    vesselName: 'MV Test',
    embarkLatitude: 18.5,
    embarkLongitude: -77.9,
    disembarkLatitude: 18.6,
    disembarkLongitude: -77.8,
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  testWidgets('renders FlutterMap voyage route for a liveaboard trip', (
    tester,
  ) async {
    const tripId = 'trip-1';
    final overrides = await getBaseOverrides();

    final sites = [
      const DiveSite(
        id: 'site-1',
        name: 'Reef One',
        location: GeoPoint(18.55, -77.85),
      ),
      const DiveSite(
        id: 'site-2',
        name: 'Reef Two',
        location: GeoPoint(18.58, -77.82),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          liveaboardDetailsProvider(
            tripId,
          ).overrideWith((ref) async => _makeDetails(tripId)),
          tripSitesWithLocationsProvider(
            tripId,
          ).overrideWith((ref) async => sites),
        ].cast(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TripVoyageMap(tripId: tripId)),
        ),
      ),
    );
    // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TripVoyageMap), findsOneWidget);
    expect(find.byType(FlutterMap), findsWidgets);
  });

  testWidgets('renders FlutterMap from dive sites only (no liveaboard ports)', (
    tester,
  ) async {
    const tripId = 'trip-2';
    final overrides = await getBaseOverrides();

    final sites = [
      const DiveSite(
        id: 'site-a',
        name: 'Reef A',
        location: GeoPoint(0.0, 0.0),
      ),
      const DiveSite(
        id: 'site-b',
        name: 'Reef B',
        location: GeoPoint(0.1, 0.1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          liveaboardDetailsProvider(tripId).overrideWith((ref) async => null),
          tripSitesWithLocationsProvider(
            tripId,
          ).overrideWith((ref) async => sites),
        ].cast(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TripVoyageMap(tripId: tripId)),
        ),
      ),
    );
    // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FlutterMap), findsWidgets);
  });
}
