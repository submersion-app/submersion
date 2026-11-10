import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveSitesCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

const _site = DiveSite(id: 'site-blue', name: 'Blue Corner');

/// Issue #4383: the dive editor offers the species other dives at the same
/// site logged as one-tap chips. What these tests pin is the page's side: the
/// chips follow the dive's site, a tap puts the species on the dive as one
/// animal, and the save writes it like any picker-added sighting.
void main() {
  late DiveRepository diveRepository;
  late SpeciesRepository speciesRepository;

  setUp(() async {
    await setUpTestDatabase();
    diveRepository = DiveRepository();
    speciesRepository = SpeciesRepository();
    final now = DateTime(2026).millisecondsSinceEpoch;
    final db = DatabaseService.instance.database;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: _site.id,
            name: _site.name,
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive buildDive(String id, {DiveSite? site}) => Dive(
    id: id,
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    entryTime: DateTime(2026, 3, 28, 10, 5),
    bottomTime: const Duration(minutes: 40),
    maxDepth: 20.0,
    site: site,
    tanks: const [],
    profile: const [],
    gear: looseGear(const []),
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  Future<void> pumpEditPage(WidgetTester tester, String diveId) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveRepositoryProvider.overrideWithValue(diveRepository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(diveRepository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        locale: const Locale('en'),
        child: DiveEditPage(diveId: diveId, embedded: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expandExperience(WidgetTester tester) async {
    final header = find.text('Experience');
    await tester.scrollUntilVisible(
      header,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  testWidgets('a tapped suggestion is saved on the dive as one animal', (
    tester,
  ) async {
    final shark = await speciesRepository.createSpecies(
      commonName: 'Test Shark',
      category: SpeciesCategory.shark,
    );
    final turtle = await speciesRepository.createSpecies(
      commonName: 'Test Turtle',
      category: SpeciesCategory.turtle,
    );
    final earlier = await diveRepository.createDive(
      buildDive('dive-earlier', site: _site),
    );
    await speciesRepository.addSighting(
      diveId: earlier.id,
      speciesId: shark.id,
      count: 4,
    );
    await speciesRepository.addExpectedSpecies(
      siteId: _site.id,
      speciesId: turtle.id,
    );
    final edited = await diveRepository.createDive(
      buildDive('dive-edited', site: _site),
    );

    await pumpEditPage(tester, edited.id);
    await expandExperience(tester);

    expect(find.text('Suggested for Blue Corner'), findsOneWidget);
    expect(find.text('Test Shark · 1'), findsOneWidget);
    expect(find.text('Test Turtle'), findsOneWidget);

    await tester.tap(find.text('Test Shark · 1'));
    await tester.pumpAndSettle();

    // The species moved from the chips to the dive's list.
    expect(find.text('Test Shark · 1'), findsNothing);
    expect(find.text('Test Shark'), findsOneWidget);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await speciesRepository.getSightingsForDive(edited.id);
    expect(saved.map((s) => (s.speciesId, s.abundance, s.notes)), [
      (shark.id, SightingAbundance.seen, ''),
    ]);
  });

  testWidgets('a dive with no site shows no suggestions', (tester) async {
    final shark = await speciesRepository.createSpecies(
      commonName: 'Test Shark',
      category: SpeciesCategory.shark,
    );
    final earlier = await diveRepository.createDive(
      buildDive('dive-earlier', site: _site),
    );
    await speciesRepository.addSighting(
      diveId: earlier.id,
      speciesId: shark.id,
    );
    final edited = await diveRepository.createDive(buildDive('dive-edited'));

    await pumpEditPage(tester, edited.id);
    await expandExperience(tester);

    expect(find.textContaining('Suggested for'), findsNothing);
    expect(find.text('Test Shark · 1'), findsNothing);
  });
}
