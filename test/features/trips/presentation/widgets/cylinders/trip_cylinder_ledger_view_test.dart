import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/pages/trip_cylinder_board_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late String tripId;
  late TripCylinder slot;
  final at = DateTime.utc(2026, 3, 9, 8);
  const units = UnitFormatter(AppSettings(defaultCurrency: 'EUR'));

  setUp(() async {
    await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
    slot = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        label: 'Truck 1',
        workingPressure: 207,
        createdAt: at,
        updatedAt: at,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<TripCylinderEvent> event(
    String id,
    TripCylinderEventKind kind, {
    required int hour,
    double? pressure,
    double? o2,
    double? cost,
  }) => repo.createEvent(
    TripCylinderEvent(
      id: id,
      tripCylinderId: slot.id,
      kind: kind,
      occurredAt: DateTime.utc(2026, 3, 9, hour),
      pressure: pressure,
      o2Percent: o2,
      cost: cost,
      createdAt: at,
      updatedAt: at,
    ),
  );

  Future<void> pumpLedger(
    WidgetTester tester, {
    TripCylinderRepository? repository,
    Future<List<TripCylinderEvent>>? ledger,
    TripFillPassportCopier? copier,
    bool unlock = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) =>
                MockSettingsNotifier(const AppSettings(defaultCurrency: 'EUR')),
          ),
          allDiveCentersProvider.overrideWith((ref) async => const []),
          if (repository != null)
            tripCylinderRepositoryProvider.overrideWithValue(repository),
          if (copier != null)
            tripFillPassportCopierProvider.overrideWithValue(copier),
          if (ledger != null)
            tripCylinderLedgerProvider(tripId).overrideWith((ref) => ledger),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCylinderBoardPage(tripId: tripId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Opened alone the board has its own lock (issue #4527, decision 9).
    if (unlock) {
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Ledger'));
    if (ledger == null) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('an empty ledger says so', (tester) async {
    await pumpLedger(tester);
    expect(find.text('No fills or adjustments yet'), findsOneWidget);
  });

  testWidgets('lists events newest first with their details', (tester) async {
    await event(
      'e1',
      TripCylinderEventKind.fill,
      hour: 8,
      pressure: 200,
      o2: 32,
      cost: 12.5,
    );
    await event('e2', TripCylinderEventKind.adjustment, hour: 14, pressure: 0);
    await pumpLedger(tester);

    final newest = tester.getTopLeft(find.byKey(const Key('ledger-e2')));
    final oldest = tester.getTopLeft(find.byKey(const Key('ledger-e1')));
    expect(newest.dy, lessThan(oldest.dy));
    expect(
      find.textContaining(
        'EAN32 · ${units.formatPressure(200)} · ${formatMoney(12.5, 'EUR')}',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Adjustment ·'), findsOneWidget);
  });

  testWidgets('deleting an entry asks first, then holds it for Save', (
    tester,
  ) async {
    await event('e1', TripCylinderEventKind.fill, hour: 8, pressure: 200);
    await pumpLedger(tester, unlock: true);

    await tester.tap(find.byKey(const Key('ledger-delete-e1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ledger-e1')), findsNothing);
    // Held in the board's sitting until its Save (issue #4527).
    expect(await repo.getEventsForCylinder(slot.id), hasLength(1));
  });

  testWidgets('tapping a fill opens it for editing', (tester) async {
    await event('e1', TripCylinderEventKind.fill, hour: 8, pressure: 200);
    await pumpLedger(tester, unlock: true);

    await tester.tap(find.byKey(const Key('ledger-e1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit fill'), findsOneWidget);
  });

  testWidgets('a ledger still loading is not called empty', (tester) async {
    final pending = Completer<List<TripCylinderEvent>>();
    await pumpLedger(tester, ledger: pending.future);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No fills or adjustments yet'), findsNothing);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No fills or adjustments yet'), findsOneWidget);
  });

  testWidgets('a ledger that fails to load says so', (tester) async {
    final failing = Completer<List<TripCylinderEvent>>();
    await pumpLedger(tester, ledger: failing.future);
    failing.completeError(StateError('db gone'));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('No fills or adjustments yet'), findsNothing);
  });
}
