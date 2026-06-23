import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ccr_settings_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Exercises the dive edit page's expanded group interiors and picker
/// flows against a fully populated dive, complementing the structural
/// tests in dive_edit_page_test.dart.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final suggestionTrip = Trip(
    id: 'trip-1',
    name: 'Maldives 2026',
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 6, 14),
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );

  Future<Dive> seedRichDive() async {
    final equipmentRepository = EquipmentRepository();
    final regulator = await equipmentRepository.createEquipment(
      const EquipmentItem(
        id: 'eq-1',
        name: 'Apeks XTX50',
        type: EquipmentType.regulator,
      ),
    );
    final mask = await equipmentRepository.createEquipment(
      const EquipmentItem(
        id: 'eq-2',
        name: 'Low Volume Mask',
        type: EquipmentType.mask,
      ),
    );
    final siteRepository = SiteRepository();
    final site = await siteRepository.createSite(
      const DiveSite(
        id: 'site-1',
        name: 'Blue Hole',
        country: 'Belize',
        region: 'Lighthouse Reef',
        location: GeoPoint(17.3158, -87.5354),
      ),
    );

    // An earlier dive the same day produces a surface interval.
    await repository.createDive(
      Dive(
        id: 'dive-earlier',
        diveNumber: 141,
        dateTime: DateTime(2026, 6, 8, 6, 0),
        entryTime: DateTime(2026, 6, 8, 6, 0),
        exitTime: DateTime(2026, 6, 8, 6, 45),
        maxDepth: 12,
        tanks: const [],
        profile: const [],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      ),
    );

    final dive = Dive(
      id: 'dive-rich',
      diveNumber: 142,
      dateTime: DateTime(2026, 6, 8, 9, 14),
      entryTime: DateTime(2026, 6, 8, 9, 14),
      exitTime: DateTime(2026, 6, 8, 10, 6),
      bottomTime: const Duration(minutes: 52),
      maxDepth: 28.4,
      avgDepth: 14.2,
      waterTemp: 24,
      airTemp: 29,
      visibility: Visibility.good,
      waterType: WaterType.salt,
      currentDirection: CurrentDirection.north,
      currentStrength: CurrentStrength.light,
      entryMethod: EntryMethod.boat,
      exitMethod: EntryMethod.boat,
      swellHeight: 0.5,
      windSpeed: 4,
      humidity: 65,
      weatherDescription: 'Sunny',
      cloudCover: CloudCover.partlyCloudy,
      precipitation: Precipitation.none,
      site: site,
      diveMode: DiveMode.ccr,
      setpointLow: 0.7,
      setpointHigh: 1.2,
      diluentGas: const GasMix(o2: 21),
      profile: [
        for (var i = 0; i <= 10; i++)
          DiveProfilePoint(timestamp: i * 300, depth: i < 9 ? 20 : 0),
      ],
      tanks: const [
        DiveTank(id: 't1', volume: 11.1, startPressure: 200, endPressure: 50),
        DiveTank(
          id: 't2',
          volume: 7,
          startPressure: 200,
          endPressure: 120,
          role: TankRole.stage,
          order: 1,
        ),
      ],
      equipment: [regulator, mask],
      notes: 'Two eagle rays at the wall',
      rating: 4,
      photoIds: const [],
      sightings: const [],
      weights: const [
        DiveWeight(
          id: 'w1',
          diveId: 'dive-rich',
          weightType: WeightType.belt,
          amountKg: 4,
        ),
        DiveWeight(
          id: 'w2',
          diveId: 'dive-rich',
          weightType: WeightType.integrated,
          amountKg: 2,
        ),
      ],
      tags: const [],
      customFields: const [
        DiveCustomField(
          id: 'cf1',
          key: 'Boat',
          value: 'Aggressor',
          sortOrder: 0,
        ),
      ],
    );
    final created = await repository.createDive(dive);

    final speciesRepository = SpeciesRepository();
    final ray = await speciesRepository.getOrCreateSpecies(
      commonName: 'Eagle Ray',
      category: SpeciesCategory.ray,
    );
    await speciesRepository.addSighting(
      diveId: created.id,
      speciesId: ray.id,
      count: 2,
      notes: 'pair',
    );
    return created;
  }

  Future<void> pumpEditor(
    WidgetTester tester,
    String? diveId, {
    void Function(String)? onSaved,
    Size surfaceSize = const Size(950, 8000),
  }) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          tripForDateProvider.overrideWith((ref, date) async => suggestionTrip),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    if (diveId != null) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> expandAllGroups(WidgetTester tester) async {
    // Editing defaults: only The Dive starts expanded; tap each summary bar.
    await tester.tap(find.textContaining('tanks'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining('Salt'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add trip or dive center'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add buddies'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining('★'));
    await tester.pumpAndSettle();
  }

  testWidgets('wide window lays the groups out in two columns', (tester) async {
    final dive = await seedRichDive();
    await pumpEditor(tester, dive.id, surfaceSize: const Size(1400, 1600));

    final theDive = tester.getTopLeft(find.text('THE DIVE'));
    final gasGear = tester.getTopLeft(find.text('GAS & GEAR'));
    final conditions = tester.getTopLeft(find.text('CONDITIONS'));

    // Left column (split after Gas & Gear): The Dive then Gas & Gear stacked.
    expect(gasGear.dx, closeTo(theDive.dx, 1));
    expect(gasGear.dy, greaterThan(theDive.dy));
    // Right column: Conditions sits beside The Dive, not below Gas & Gear.
    expect(conditions.dx, greaterThan(theDive.dx + 100));
    expect(conditions.dy, lessThan(gasGear.dy));
  });

  testWidgets('rich dive renders every expanded group interior', (
    tester,
  ) async {
    final dive = await seedRichDive();
    await pumpEditor(tester, dive.id);
    await expandAllGroups(tester);

    // The Dive: surface interval from the earlier dive, site caption,
    // profile block with points and edit button.
    expect(find.text('Surface interval'), findsOneWidget);
    expect(find.textContaining('Belize'), findsWidgets);
    expect(find.text('11 points'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    // Profile-derived one-tap calculate buttons on the metric rows.
    expect(find.byIcon(Icons.calculate_outlined), findsWidgets);

    // Gas & Gear: CCR panel, two tank cards, equipment and weights blocks.
    expect(find.byType(CcrSettingsPanel), findsOneWidget);
    expect(find.textContaining('Tank 1'), findsOneWidget);
    expect(find.textContaining('Tank 2'), findsOneWidget);
    expect(find.textContaining('Weight'), findsWidgets);

    // Conditions: dropdowns and weather fields are populated.
    expect(find.text('Sunny'), findsOneWidget);

    // Trip: suggestion banner offers the date-matched trip.
    expect(find.textContaining('Maldives 2026'), findsWidgets);

    // Gas & Gear equipment block lists the attached items.
    expect(find.text('Apeks XTX50'), findsOneWidget);
    expect(find.text('Low Volume Mask'), findsOneWidget);

    // Experience: sighting tile and notes.
    expect(find.text('Eagle Ray'), findsOneWidget);
    expect(find.text('Two eagle rays at the wall'), findsOneWidget);
  });

  testWidgets('interactions: suggestions, clears, sheets and weights', (
    tester,
  ) async {
    final dive = await seedRichDive();
    await pumpEditor(tester, dive.id);
    await expandAllGroups(tester);

    // Accept the suggested trip; its date-range caption appears.
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect(find.text('Maldives 2026'), findsWidgets);

    // Row clear affordances are ordered by tree position: the site row
    // (in The Dive) comes before the trip row.
    expect(find.text('Blue Hole'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear).at(0));
    await tester.pumpAndSettle();
    expect(find.text('Add site'), findsOneWidget);

    // With the site cleared, the first remaining clear is the trip's.
    await tester.tap(find.byIcon(Icons.clear).first);
    await tester.pumpAndSettle();

    // Open the sighting editor from the tile and dismiss it.
    await tester.tap(find.text('Eagle Ray'));
    await tester.pumpAndSettle();
    expect(find.byType(EditSightingSheet), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Weights: add a row, then delete it again.
    final weightFields = find.byIcon(Icons.delete_outline);
    final before = tester.widgetList(weightFields).length;
    await tester.tap(find.text('Add Weight Entry'));
    await tester.pumpAndSettle();
    expect(tester.widgetList(weightFields).length, before + 1);
    await tester.tap(weightFields.last);
    await tester.pumpAndSettle();

    // Rating star tap fires the rating row.
    await tester.tap(find.byIcon(Icons.star_border).last);
    await tester.pump();

    // CCR panel edit fires the named-args onChanged plumbing.
    final ccrField = find.descendant(
      of: find.byType(CcrSettingsPanel),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(ccrField.first, '0.8');
    await tester.pump();
  });

  testWidgets('entry and exit rows open the date and time pickers', (
    tester,
  ) async {
    final dive = await seedRichDive();
    await pumpEditor(tester, dive.id);

    await tester.tap(find.text('Entry'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  testWidgets('rare sections expand from the add row and accept input', (
    tester,
  ) async {
    final dive = await seedRichDive();
    await pumpEditor(tester, dive.id);

    await tester.tap(find.text('Training Course'));
    await tester.pumpAndSettle();
    expect(find.text('TRAINING COURSE'), findsOneWidget);

    // The seeded custom field means its section renders directly rather
    // than hiding behind the add row.
    expect(find.text('CUSTOM FIELDS'), findsOneWidget);
    await tester.tap(find.text('Add Field'));
    await tester.pumpAndSettle();
  });

  testWidgets('save expands collapsed groups before validating', (
    tester,
  ) async {
    String? savedId;
    await pumpEditor(tester, null, onSaved: (id) => savedId = id);

    // New dives keep several groups collapsed, so saving runs the
    // expand-before-validate path.
    await tester.tap(find.text('Save'));
    // Bounded pumps: the new-dive GPS capture timer never settles in tests.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(savedId, isNotNull);
  });
}
