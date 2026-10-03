import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Records the saved trip without the list notifier's own reloads.
class _RecordingTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _RecordingTripListNotifier() : super(const AsyncValue.data([]));

  final updated = <Trip>[];

  @override
  Future<void> updateTrip(Trip trip) async => updated.add(trip);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Leaving the liveaboard type keeps the itinerary: every trip type has one
/// now (#2845). Only the vessel details, which only a liveaboard has, go.
void main() {
  late String tripId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime(2026, 1, 1);
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Raja Ampat',
        startDate: DateTime(2026, 11, 3),
        endDate: DateTime(2026, 11, 6),
        tripType: TripType.liveaboard,
        liveaboardName: 'MV Explorer',
        createdAt: now,
        updatedAt: now,
      ),
    );
    tripId = trip.id;
    await LiveaboardDetailsRepository().createOrUpdate(
      LiveaboardDetails(
        id: '',
        tripId: tripId,
        vesselName: 'MV Explorer',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await ItineraryDayRepository().saveAll(
      ItineraryDay.generateForTrip(
        tripId: tripId,
        startDate: trip.startDate,
        endDate: trip.endDate,
      ).map((d) => d.copyWith(notes: 'Planned')).toList(),
    );
  });
  tearDown(tearDownTestDatabase);

  testWidgets('changing a liveaboard to a resort trip keeps its itinerary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final notifier = _RecordingTripListNotifier();
    final router = GoRouter(
      initialLocation: '/trips/$tripId/edit',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (_, _) => const Scaffold(body: Text('LIST')),
          routes: [
            GoRoute(
              path: ':id/edit',
              builder: (_, s) => TripEditPage(tripId: s.pathParameters['id']),
            ),
          ],
        ),
      ],
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) => notifier),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      // The page reads the trip and its vessel from the database.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Raja Ampat'), findsOneWidget);

    await tester.tap(find.text('Resort'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(notifier.updated.single.tripType, TripType.resort);
    final days = await tester.runAsync(
      () => ItineraryDayRepository().getByTripId(tripId),
    );
    final details = await tester.runAsync(
      () => LiveaboardDetailsRepository().getByTripId(tripId),
    );
    expect(days, hasLength(4));
    expect(days!.every((d) => d.notes == 'Planned'), isTrue);
    expect(details, isNull);
  });
}
