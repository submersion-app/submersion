import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late TripCylinder slot;
  final presets = [
    TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!),
    TankPresetEntity.fromBuiltIn(TankPresets.byName('steel12')!),
  ];

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
        volume: 11.1,
        workingPressure: 207,
        material: TankMaterial.aluminum,
        presetName: 'al80',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
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
          tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTripCylinderEditSheet(context, cylinder: slot),
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

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  testWidgets('saves a renamed slot with a custom metric size', (tester) async {
    await pumpAndOpen(tester);
    expect(find.text('Edit cylinder'), findsOneWidget);

    await tester.enterText(field('Label'), 'Truck A');
    await tester.enterText(field('Size (L)'), '10.8');
    await tester.enterText(field('Note'), 'sticky valve');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getCylinderById(slot.id))!;
    expect(stored.label, 'Truck A');
    expect(stored.volume, 10.8);
    expect(stored.workingPressure, 207);
    // Typing a size makes it a custom cylinder.
    expect(stored.presetName, isNull);
    expect(stored.notes, 'sticky valve');
    expect(find.text('Edit cylinder'), findsNothing);
  });

  testWidgets('picking a preset fills and stores its specs', (tester) async {
    await pumpAndOpen(tester);
    await tester.tap(find.text(presets.first.displayName).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(presets.last.displayName).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getCylinderById(slot.id))!;
    expect(stored.presetName, presets.last.name);
    expect(stored.volume, presets.last.volumeLiters);
    expect(stored.workingPressure, presets.last.workingPressureBar);
    expect(stored.material, presets.last.material);
  });

  testWidgets('imperial capacity converts back to liters on save', (
    tester,
  ) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await pumpAndOpen(tester, settings: imperial);

    await tester.enterText(field('Working pressure (psi)'), '3000');
    await tester.enterText(field('Size (cuft)'), '80');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getCylinderById(slot.id))!;
    expect(stored.workingPressure, closeTo(206.84, 0.01));
    expect(
      stored.volume,
      closeTo(80 * 28.3168 / stored.workingPressure!, 1e-6),
    );
  });

  testWidgets('refuses an unreadable size and keeps the sheet open', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.enterText(field('Size (L)'), 'big');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid number (decimal separator: ".")'),
      findsOneWidget,
    );
    expect((await repo.getCylinderById(slot.id))!.volume, 11.1);
  });

  testWidgets('refuses a blank label and keeps the sheet open', (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(field('Label'), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a label.'), findsOneWidget);
    expect((await repo.getCylinderById(slot.id))!.label, 'Truck 1');
  });

  testWidgets('an imperial size needs a working pressure to convert', (
    tester,
  ) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await pumpAndOpen(tester, settings: imperial);

    await tester.enterText(field('Working pressure (psi)'), '');
    await tester.enterText(field('Size (cuft)'), '80');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Enter the working pressure too, so the size can be converted.',
      ),
      findsOneWidget,
    );
    expect((await repo.getCylinderById(slot.id))!.volume, 11.1);
  });

  testWidgets('a typed working pressure makes the slot custom', (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(field('Working pressure (bar)'), '232');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getCylinderById(slot.id))!;
    expect(stored.workingPressure, 232);
    expect(stored.presetName, isNull);
  });
}
