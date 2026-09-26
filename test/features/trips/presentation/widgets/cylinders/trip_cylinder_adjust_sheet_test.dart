import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late TripCylinder slot;

  setUp(() async {
    await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    );
    slot = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: trip.id,
        label: 'Truck 1',
        workingPressure: 207,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    TripCylinderEvent? editing,
    MockSettingsNotifier? settings,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => settings ?? MockSettingsNotifier(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTripCylinderAdjustSheet(
                  context,
                  cylinder: slot,
                  editing: editing,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('records a gauge reading', (tester) async {
    await pumpAndOpen(tester);
    expect(find.text('Adjust'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('adjust-pressure')), '120');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(slot.id)).single;
    expect(e.kind, TripCylinderEventKind.adjustment);
    expect(e.pressure, 120);
    expect(e.o2Percent, isNull);
  });

  testWidgets('mark empty records zero, in psi too', (tester) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await pumpAndOpen(tester, settings: imperial);
    expect(find.text('Pressure (psi)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('adjust-mark-empty')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(slot.id)).single;
    expect(e.pressure, 0);
  });

  testWidgets('a re-analyzed mix is stored with helium defaulting to 0', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.enterText(find.byKey(const Key('adjust-o2')), '31');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(slot.id)).single;
    expect(e.o2Percent, 31);
    expect(e.hePercent, 0);
    expect(e.pressure, isNull);
  });

  testWidgets('helium without oxygen is refused', (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(find.byKey(const Key('adjust-he')), '35');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Oxygen must be 1 to 100 percent, helium 0 to 99, and together at most 100.',
      ),
      findsOneWidget,
    );
    expect(await repo.getEventsForCylinder(slot.id), isEmpty);
  });

  testWidgets('edits an adjustment in place, converting its pressure', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final existing = await repo.createEvent(
      TripCylinderEvent(
        id: '',
        tripCylinderId: slot.id,
        kind: TripCylinderEventKind.adjustment,
        occurredAt: DateTime.utc(2026, 3, 9, 14),
        pressure: 100,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await pumpAndOpen(tester, editing: existing, settings: imperial);
    expect(find.text('Edit adjustment'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('adjust-pressure')), '1000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    const psi = UnitFormatter(AppSettings(pressureUnit: PressureUnit.psi));
    final events = await repo.getEventsForCylinder(slot.id);
    expect(events, hasLength(1));
    expect(events.single.pressure, closeTo(psi.pressureToBar(1000), 1e-9));
    expect(events.single.occurredAt, DateTime.utc(2026, 3, 9, 14));
  });
}
