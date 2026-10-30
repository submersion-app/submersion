import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Creates trips for real, and fails the first dive move.
class _FlakyMoveNotifier extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _FlakyMoveNotifier() : super(const AsyncValue.data([]));

  var failMoves = 1;
  final created = <String>[];

  @override
  Future<Trip> addTrip(Trip trip) async {
    final saved = await TripRepository().createTrip(trip);
    created.add(saved.id);
    return saved;
  }

  @override
  Future<void> updateTrip(Trip trip) => TripRepository().updateTrip(trip);

  @override
  Future<void> assignDivesToTrip(
    List<String> diveIds,
    String tripId, {
    Set<String>? oldTripIds,
  }) async {
    if (failMoves > 0) {
      failMoves--;
      throw StateError('database is locked');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A save that failed after the trip was created, then retried (issue
/// #3658): the retry finishes the same trip, with one set of vessel details
/// and one itinerary.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('a retried liveaboard save writes its details once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final notifier = _FlakyMoveNotifier();
    final draft = TripDraft(
      trip: Trip(
        id: '',
        name: 'Raja Ampat',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 11),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      diveIds: const ['d1'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tripListNotifierProvider.overrideWith((ref) => notifier),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          shareByDefaultProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripEditPage(draft: draft),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liveaboard'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vessel Name *'),
      'MV Explorer',
    );

    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();
    }

    expect(notifier.created, hasLength(1));
    final tripId = notifier.created.single;
    final details = await tester.runAsync(
      () => TripRepository().getTripById(tripId),
    );
    expect(details, isNotNull);
    final days = await tester.runAsync(
      () => ItineraryDayRepository().getByTripId(tripId),
    );
    expect(days, hasLength(4));
    final vessels = await tester.runAsync(
      () => DatabaseService.instance.database
          .customSelect(
            'SELECT COUNT(*) AS n FROM liveaboard_detail_records '
            'WHERE trip_id = ?',
            variables: [Variable.withString(tripId)],
          )
          .getSingle(),
    );
    expect(vessels!.read<int>('n'), 1);
  });
}
