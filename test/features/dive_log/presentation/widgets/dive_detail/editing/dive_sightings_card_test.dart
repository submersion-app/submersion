import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/species_profile_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/sightings_editor.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The Sightings card of the dive page, edited in place (issue #4527,
/// plan 6).
void main() {
  late AppDatabase db;
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026, 3, 9));
  const manta = Sighting(
    id: 'fresh',
    diveId: 'd1',
    speciesId: 'manta',
    speciesName: 'Manta',
    speciesCategory: SpeciesCategory.ray,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    for (final (id, name) in [('turtle', 'Green turtle'), ('manta', 'Manta')]) {
      await db.customStatement(
        "INSERT INTO species (id, common_name, category) VALUES ('$id', "
        "'$name', 'other')",
      );
    }
    await SpeciesRepository().addSighting(diveId: 'd1', speciesId: 'turtle');
  });
  tearDown(tearDownTestDatabase);

  Future<RecordEditController<Dive>> pump(
    WidgetTester tester,
    Dive d, {
    bool open = true,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = RecordEditController<Dive>(
      onSave: (_) async {},
      onStart: (session) => diveSightingsList.load(session),
    )..unlock(d);
    addTearDown(controller.dispose);
    if (open) controller.openCard(DiveDetailSectionId.sightings.name);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await getBaseOverrides(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) =>
                      controller.openCardIds.contains('sightings')
                      ? DiveSightingsCardEditor(session: controller.session!)
                      : DiveSightingsSection(
                          dive: controller.session!.working,
                          topGap: 0,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  SightingsEditor editor(WidgetTester tester) =>
      tester.widget<SightingsEditor>(find.byType(SightingsEditor));

  testWidgets('opening and closing leaves the sitting clean', (tester) async {
    final c = await pump(tester, dive);
    expect(editor(tester).sightings.map((s) => s.speciesId), ['turtle']);
    expect(editor(tester).showTitle, isFalse);
    c.closeCard('sightings');
    await tester.pumpAndSettle();
    expect(c.session!.isDirty, isFalse);
  });

  testWidgets('a species picked reaches the sitting, and the read card shows '
      'it after Done', (tester) async {
    final c = await pump(tester, dive);
    editor(tester).onChanged([...editor(tester).sightings, manta]);
    await tester.pumpAndSettle();
    expect(c.session!.changedCardIds, {'sightings'});

    c.closeCard('sightings');
    await tester.pumpAndSettle();
    expect(find.text('Manta'), findsOneWidget);
    expect(find.text('Green turtle'), findsOneWidget);
  });

  testWidgets('suggestions follow a site picked on the header in the same '
      'sitting', (tester) async {
    final c = await pump(tester, dive);
    expect(editor(tester).siteId, isNull);

    c.session!.set(diveSiteField, const DiveSite(id: 'reef', name: 'Reef'));
    await tester.pump();
    expect(editor(tester).siteId, 'reef');
    expect(editor(tester).siteName, 'Reef');
    expect(editor(tester).excludeDiveId, 'd1');
  });

  testWidgets('no sightings: the card is empty in a sitting, and so offered '
      'in the strip', (tester) async {
    await db.customStatement('DELETE FROM sightings');
    final c = await pump(tester, dive, open: false);
    final card = diveEditCards[DiveDetailSectionId.sightings]!;
    expect(card.isEmpty(dive), isFalse);
    expect(card.isEmptyInSitting!(c.session!), isTrue);
  });

  testWidgets('a read that fails says so, and Try again reads them', (
    tester,
  ) async {
    await tester.runAsync(
      () => db.customStatement('ALTER TABLE sightings RENAME TO away'),
    );
    await pump(tester, dive);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('This card could not be loaded.'), findsOneWidget);

    await tester.runAsync(
      () => db.customStatement('ALTER TABLE away RENAME TO sightings'),
    );
    await tester.tap(find.text('Try again'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('This card could not be loaded.'), findsNothing);
    expect(find.text('Green turtle'), findsOneWidget);
  });

  group('where on the dive each species was seen (issue #5092)', () {
    final profiled = Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026, 3, 9),
      profile: [
        for (var t = 0; t <= 600; t += 10)
          DiveProfilePoint(timestamp: t, depth: t / 20),
      ],
    );

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(DiveSightingsSection)),
        );

    testWidgets('a timed sighting shows its depth, and its chip selects it '
        'on the profile', (tester) async {
      await SpeciesRepository().addSighting(
        diveId: 'd1',
        speciesId: 'manta',
        seenAtSeconds: 300,
      );
      await pump(tester, profiled, open: false);

      expect(find.text('15 m'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sighting_depth')));
      await tester.pumpAndSettle();
      expect(
        containerOf(tester).read(selectedProfileSpeciesProvider('d1')),
        'manta',
      );
    });

    testWidgets('a timed sighting on a dive with no profile reads its time', (
      tester,
    ) async {
      await SpeciesRepository().addSighting(
        diveId: 'd1',
        speciesId: 'manta',
        seenAtSeconds: 750,
      );
      await pump(tester, dive, open: false);

      expect(find.text('at 12:30'), findsOneWidget);
      expect(find.byKey(const ValueKey('sighting_depth')), findsNothing);
    });

    testWidgets('deleting the selected sighting clears the selection', (
      tester,
    ) async {
      final manta = await SpeciesRepository().addSighting(
        diveId: 'd1',
        speciesId: 'manta',
        seenAtSeconds: 300,
      );
      await pump(tester, profiled, open: false);
      await tester.tap(find.byKey(const ValueKey('sighting_depth')));
      await tester.pumpAndSettle();

      // The base overrides stub the dive repository whose change stream
      // refreshes the sightings, so the test refreshes them itself.
      await tester.runAsync(() => SpeciesRepository().deleteSighting(manta.id));
      containerOf(tester).invalidate(diveSightingsProvider('d1'));
      await tester.pumpAndSettle();
      expect(find.text('Manta'), findsNothing);
      expect(
        containerOf(tester).read(selectedProfileSpeciesProvider('d1')),
        isNull,
      );
    });
  });
}
