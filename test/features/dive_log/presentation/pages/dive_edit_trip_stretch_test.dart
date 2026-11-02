import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Saving a dive outside its trip stretches the trip and says so (issue
/// #3351). Drives the real editor against a real database.
void main() {
  late DiveRepository dives;
  late TripRepository trips;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    trips = TripRepository();
  });
  tearDown(tearDownTestDatabase);

  final entry = DateTime.utc(2026, 1, 15, 10);

  Future<Trip> addTrip() async {
    final now = DateTime(2025, 12, 1);
    return trips.createTrip(
      Trip(
        id: 'roatan',
        name: 'Roatan',
        startDate: DateTime(2026, 1, 5),
        endDate: DateTime(2026, 1, 10),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? diveId,
    String? tripId,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(dives),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(dives, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              tripId: tripId,
              embedded: true,
              onSaved: (_) {},
            ),
          ),
        ),
      ),
    );
    // A new dive starts a 10 s GPS capture, so pumpAndSettle never returns;
    // pump in bounded steps.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pickTrip(WidgetTester tester) async {
    final tripRow = find.ancestor(
      of: find.text('Trip'),
      matching: find.byType(FormRow),
    );
    if (tripRow.evaluate().isEmpty) {
      await tester.ensureVisible(find.text('Trip').first);
      await tester.tap(find.text('Trip').first);
      await tester.pumpAndSettle();
    }
    final row = tripRow.first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roatan').last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('a new dive on a past trip stretches it and says so', (
    tester,
  ) async {
    await addTrip();
    await pumpEditor(tester, tripId: 'roatan');

    await tester.tap(find.text('Save'));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }

    final trip = (await trips.getTripById('roatan'))!;
    final today = DateTime.now();
    expect(trip.endDate, DateTime(today.year, today.month, today.day));
    expect(find.textContaining('Roatan now runs'), findsOneWidget);
  });

  testWidgets('moving a dive onto a trip stretches it and says so', (
    tester,
  ) async {
    await addTrip();
    await dives.createDive(Dive(id: 'd', dateTime: entry, entryTime: entry));
    await pumpEditor(tester, diveId: 'd');

    await pickTrip(tester);
    await save(tester);

    expect((await trips.getTripById('roatan'))!.endDate, DateTime(2026, 1, 15));
    expect(find.textContaining('Roatan now runs'), findsOneWidget);
  });

  testWidgets('redating a dive on a trip stretches it', (tester) async {
    await addTrip();
    await dives.createDive(
      Dive(
        id: 'd',
        dateTime: DateTime.utc(2026, 1, 7, 10),
        entryTime: DateTime.utc(2026, 1, 7, 10),
        tripId: 'roatan',
      ),
    );
    await pumpEditor(tester, diveId: 'd');

    final entryRow = find
        .ancestor(of: find.text('Entry'), matching: find.byType(FormRow))
        .first;
    await tester.ensureVisible(entryRow);
    await tester.pumpAndSettle();
    await tester.tap(entryRow);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('20'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // date
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); // time
    await tester.pumpAndSettle();
    await save(tester);

    expect((await trips.getTripById('roatan'))!.endDate, DateTime(2026, 1, 20));
  });

  testWidgets('saving an out-of-range dive unchanged leaves its trip', (
    tester,
  ) async {
    await addTrip();
    await dives.createDive(
      Dive(id: 'd', dateTime: entry, entryTime: entry, tripId: 'roatan'),
    );
    await pumpEditor(tester, diveId: 'd');

    await save(tester);

    expect((await trips.getTripById('roatan'))!.endDate, DateTime(2026, 1, 10));
    expect(find.textContaining('now runs'), findsNothing);
  });
}
