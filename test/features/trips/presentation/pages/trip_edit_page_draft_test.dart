import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _RecordingNotifier extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _RecordingNotifier() : super(const AsyncValue.data([]));

  Trip? added;
  int adds = 0;
  int updates = 0;
  int assigns = 0;
  int failAssigns = 0;
  List<String>? assignedIds;
  String? assignedTripId;
  Set<String>? assignedOldTripIds;

  @override
  Future<Trip> addTrip(Trip trip) async {
    adds++;
    added = trip;
    return trip.copyWith(id: 'new-trip');
  }

  @override
  Future<void> assignDivesToTrip(
    List<String> diveIds,
    String tripId, {
    Set<String>? oldTripIds,
  }) async {
    assigns++;
    if (failAssigns > 0) {
      failAssigns--;
      throw StateError('database is locked');
    }
    assignedIds = diveIds;
    assignedTripId = tripId;
    assignedOldTripIds = oldTripIds;
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    updates++;
    added = trip;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScanCountingRepository implements TripRepository {
  int scans = 0;

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async {
    scans++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The new-trip form opened from selected dives (issue #3658): prefilled
/// from the draft, and on save it takes exactly those dives with no
/// date-range assignment prompt.
void main() {
  final indonesia = Trip(
    id: 'p',
    name: 'Indonesia',
    startDate: DateTime(2026, 3, 2),
    endDate: DateTime(2026, 3, 16),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final draft = TripDraft(
    trip: Trip(
      id: '',
      name: 'Raja Ampat, Mar 2026',
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 11),
      location: 'Raja Ampat, Indonesia',
      resortName: 'Kri Eco',
      parentTripId: 'p',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    diveIds: const ['d1', 'd2'],
    sourceTripIds: const {'p'},
  );

  testWidgets('the draft fills the form and its dives move on save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final notifier = _RecordingNotifier();
    final repository = _ScanCountingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tripListNotifierProvider.overrideWith((ref) => notifier),
          tripRepositoryProvider.overrideWithValue(repository),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          shareByDefaultProvider.overrideWith((ref) async => false),
          visibleTripProvider('p').overrideWith((ref) async => indonesia),
          hasSideTripsProvider('p').overrideWith((ref) async => false),
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

    expect(find.text('Raja Ampat, Mar 2026'), findsOneWidget);
    expect(find.text('Raja Ampat, Indonesia'), findsOneWidget);
    expect(find.text('Kri Eco'), findsOneWidget);
    expect(find.text('Indonesia'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final added = notifier.added!;
    expect(added.startDate, DateTime(2026, 3, 8));
    expect(added.endDate, DateTime(2026, 3, 11));
    expect(added.parentTripId, 'p');
    expect(notifier.assignedIds, ['d1', 'd2']);
    expect(notifier.assignedTripId, 'new-trip');
    expect(notifier.assignedOldTripIds, {'p'});
    expect(repository.scans, 0);
  });

  testWidgets('a failed move retried saves the same trip, not a second', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final notifier = _RecordingNotifier()..failAssigns = 1;
    final repository = _ScanCountingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tripListNotifierProvider.overrideWith((ref) => notifier),
          tripRepositoryProvider.overrideWithValue(repository),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          shareByDefaultProvider.overrideWith((ref) async => false),
          visibleTripProvider('p').overrideWith((ref) async => indonesia),
          hasSideTripsProvider('p').overrideWith((ref) async => false),
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

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.adds, 1);
    expect(notifier.assignedIds, isNull);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.adds, 1);
    expect(notifier.updates, 1);
    expect(notifier.added!.id, 'new-trip');
    expect(notifier.assignedIds, ['d1', 'd2']);
    expect(notifier.assignedTripId, 'new-trip');
  });
}
