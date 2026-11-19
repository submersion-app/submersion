import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    hide DiveSite, SiteFeature, Species, Tag;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_collection_card_editors.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_header_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_header.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_tags_card.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/widgets/site_marine_life_section.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/features/site_scape/presentation/site_features_section.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import 'site_editor_harness.dart';

/// The site's collections edited in place, held until Save (issue #4527,
/// phase 2, plan 3).
void main() {
  late AppDatabase db;
  const site = DiveSite(id: 's1', name: 'Blue Hole');
  final at = DateTime.utc(2026);
  SiteTypeEntity type(String id, String name) => SiteTypeEntity(
    id: id,
    name: name,
    isBuiltIn: false,
    createdAt: at,
    updatedAt: at,
  );
  final wreck = type('t-wreck', 'Old wreck');
  final reef = type('t-reef', 'House reef');

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Blue Hole', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO site_types (id, name, is_built_in, sort_order, "
      "created_at, updated_at) VALUES "
      "('t-wreck', 'Old wreck', 0, 0, 0, 0), ('t-reef', 'House reef', 0, 1, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) "
      "VALUES ('t1', 'To try', 0, 0, 0, 1), ('t2', 'Avoid', 0, 0, 0, 1)",
    );
    await SiteClassificationRepository().replaceTypes('s1', ['t-wreck']);
    await SiteClassificationRepository().replaceTags('s1', ['t1']);
  });

  tearDown(tearDownTestDatabase);

  group('the header block', () {
    testWidgets('tapping a type chip holds it and dots the header', (
      tester,
    ) async {
      final h = await pumpSiteEditor(
        tester,
        site,
        (session) => SiteHeaderCardEditor(session: session),
        onStart: siteTypesList.load,
        overrides: [
          siteTypesProvider.overrideWith((_) async => [wreck, reef]),
        ],
      );

      await tester.tap(find.widgetWithText(FilterChip, 'House reef'));
      await tester.pumpAndSettle();

      expect(h.session.changedCardIds, {siteHeaderCardId});
      expect(siteTypesList.current(h.session)!.map((t) => t.id), [
        't-wreck',
        't-reef',
      ]);
      // Held: nothing written yet.
      final stored = await SiteClassificationRepository().getTypesForSite('s1');
      expect(stored.map((t) => t.id), ['t-wreck']);
    });

    // Issue #401, the form's case on the header block (plan 7): a hidden
    // built-in type the site has is offered, and stays once unticked.
    testWidgets('a hidden type the site has stays offered, even once '
        'unticked', (tester) async {
      await SiteClassificationRepository().replaceTypes('s1', ['wall']);
      SiteTypeEntity builtIn(String id, String name) => SiteTypeEntity(
        id: id,
        name: name,
        isBuiltIn: true,
        createdAt: at,
        updatedAt: at,
      );
      final h = await pumpSiteEditor(
        tester,
        site,
        (session) => SiteHeaderCardEditor(session: session),
        onStart: siteTypesList.load,
        settings: AppSettings(
          hiddenBuiltInIds: {
            BuiltInCatalog.siteTypes.key: {'wall', 'lake'},
          },
        ),
        overrides: [
          siteTypesProvider.overrideWith(
            (_) async => [builtIn('wall', 'Wall'), builtIn('lake', 'Lake')],
          ),
        ],
      );
      await tester.pumpAndSettle();
      final wall = find.byWidgetPredicate((w) => w is FilterChip && w.selected);
      expect(wall, findsOneWidget);
      expect(find.byType(FilterChip), findsOneWidget);

      await tester.tap(find.byType(FilterChip));
      await tester.pumpAndSettle();

      expect(find.byType(FilterChip), findsOneWidget);
      expect(wall, findsNothing);
      expect(siteTypesList.current(h.session), isEmpty);
    });

    testWidgets('the header shows the types it is given', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: (await getBaseOverrides()).cast<Override>(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteDetailHeader(site: site, types: [reef]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('House reef'), findsOneWidget);
      expect(find.text('Old wreck'), findsNothing);
    });
  });

  group('the Tags card', () {
    Tag tag(String id, String name) =>
        Tag(id: id, name: name, createdAt: at, updatedAt: at);

    testWidgets('adding a tag holds it', (tester) async {
      final h = await pumpSiteEditor(
        tester,
        site,
        (session) => SiteTagsCardEditor(session: session),
        onStart: siteTagsList.load,
      );
      final block = tester.widget<TagFormBlock>(find.byType(TagFormBlock));
      expect(block.selectedTags.map((t) => t.id), ['t1']);

      block.onTagsChanged([...block.selectedTags, tag('t2', 'Avoid')]);
      await tester.pumpAndSettle();

      expect(h.session.changedCardIds, {'tags'});
      final stored = await SiteClassificationRepository().getTagsForSite('s1');
      expect(stored.map((t) => t.id), ['t1']);
    });

    // Browse picks from the site tags, as the form's did (plan 7).
    testWidgets('the card picks from the site tags', (tester) async {
      await pumpSiteEditor(
        tester,
        site,
        (session) => SiteTagsCardEditor(session: session),
        onStart: siteTagsList.load,
      );

      expect(
        tester.widget<TagFormBlock>(find.byType(TagFormBlock)).scope,
        TagScope.sites,
      );
    });

    testWidgets('the tags card shows the tags it is given', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: (await getBaseOverrides()).cast<Override>(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteTagsCard(siteId: 's1', tags: [tag('t2', 'Avoid')]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avoid'), findsOneWidget);
      expect(find.text('To try'), findsNothing);
    });
  });

  group('the Marine Life card', () {
    late Species turtle;
    late Species manta;

    setUp(() async {
      final repository = SpeciesRepository();
      turtle = await repository.createSpecies(
        commonName: 'Green turtle',
        category: SpeciesCategory.turtle,
      );
      manta = await repository.createSpecies(
        commonName: 'Manta',
        category: SpeciesCategory.ray,
      );
      await repository.addExpectedSpecies(siteId: 's1', speciesId: turtle.id);
    });

    testWidgets('picking species holds them and dots the card', (tester) async {
      final h = await pumpSiteEditor(
        tester,
        site,
        (session) => SiteSpeciesCardEditor(
          session: session,
          pickSpecies: (_, selected) async => {...selected, manta.id},
        ),
        onStart: siteSpeciesList.load,
      );
      expect(find.text('Green turtle'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(h.session.changedCardIds, {'marineLife'});
      expect(find.text('Manta'), findsOneWidget);
      final stored = await SpeciesRepository().getExpectedSpeciesForSite('s1');
      expect(stored.map((e) => e.speciesId), [turtle.id]);
    });

    testWidgets('a species lookup that fails changes nothing and says so', (
      tester,
    ) async {
      final h = await pumpSiteEditor(
        tester,
        site,
        (session) => SiteSpeciesCardEditor(
          session: session,
          pickSpecies: (_, selected) async => {...selected, manta.id},
          findSpecies: (_) async => throw StateError('offline'),
        ),
        onStart: siteSpeciesList.load,
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(h.session.isDirty, isFalse);
      expect(
        find.text(
          AppLocalizationsEn().marineLife_siteSection_errorLoadingExpected,
        ),
        findsOneWidget,
      );
    });

    testWidgets('removing a species holds it', (tester) async {
      final h = await pumpSiteEditor(
        tester,
        site,
        (session) => SiteSpeciesCardEditor(session: session),
        onStart: siteSpeciesList.load,
      );

      tester
          .widget<InputChip>(find.widgetWithText(InputChip, 'Green turtle'))
          .onDeleted!();
      await tester.pumpAndSettle();

      expect(siteSpeciesList.current(h.session), isEmpty);
      expect(h.session.changedCardIds, {'marineLife'});
    });

    testWidgets('the section shows the species it is given', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: (await getBaseOverrides()).cast<Override>(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SiteMarineLifeSection(
                  siteId: 's1',
                  species: [newSiteSpeciesEntry('s1', manta)],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manta'), findsOneWidget);
      expect(find.text('Green turtle'), findsNothing);
    });
  });

  group('the Features card', () {
    const gpsSite = DiveSite(
      id: 's1',
      name: 'Blue Hole',
      location: GeoPoint(12, -68),
    );
    late SiteFeature buoy;

    setUp(() async {
      buoy = await SiteFeatureRepository().addFeature(
        siteId: 's1',
        typeName: 'mooring',
        latitude: 12,
        longitude: -68,
        name: 'Buoy',
      );
    });

    Future<SiteEditorHarness> pumpFeatures(
      WidgetTester tester,
      SiteFeatureSheetResult? answer,
    ) => pumpSiteEditor(
      tester,
      gpsSite,
      (session) => SiteFeaturesCardEditor(
        session: session,
        openSheet: (_, {existing, initialDepthMeters}) async => answer,
      ),
      onStart: siteFeaturesList.load,
    );

    testWidgets('editing a feature in the sheet holds it', (tester) async {
      final h = await pumpFeatures(
        tester,
        const SiteFeatureSheetSave(
          typeName: 'mooring',
          name: 'Red buoy',
          bearingDeg: null,
          depthMeters: 6,
          notes: '',
        ),
      );

      await tester.tap(find.text('Buoy'));
      await tester.pumpAndSettle();

      expect(h.session.changedCardIds, {'features'});
      expect(find.text('Red buoy'), findsOneWidget);
      final stored = await SiteFeatureRepository().getFeaturesForSite('s1');
      expect(stored.single.name, 'Buoy');
    });

    testWidgets('removing in the sheet holds it', (tester) async {
      final h = await pumpFeatures(tester, const SiteFeatureSheetDelete());

      await tester.tap(find.text('Buoy'));
      await tester.pumpAndSettle();

      expect(siteFeaturesList.current(h.session), isEmpty);
      final stored = await SiteFeatureRepository().getFeaturesForSite('s1');
      expect(stored.single.id, buoy.id);
    });

    testWidgets('no Add feature once the coordinates are cleared', (
      tester,
    ) async {
      final placed = <EditSession<DiveSite>>[];
      final h = await pumpSiteEditor(
        tester,
        gpsSite,
        (session) => SiteFeaturePlacementScope(
          placeOnMap: placed.add,
          child: SiteFeaturesCardEditor(session: session),
        ),
        onStart: siteFeaturesList.load,
      );
      expect(
        find.byKey(const ValueKey('siteFeatureAddButton')),
        findsOneWidget,
      );

      // Cleared on the Location card in the same sitting: nowhere to place.
      h.session.set(siteLocationField, null);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('siteFeatureAddButton')), findsNothing);
    });

    testWidgets('the section shows the features it is given', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: (await getBaseOverrides()).cast<Override>(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteFeaturesSection(
                siteId: 's1',
                features: [buoy.copyWith(name: 'Held buoy')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Held buoy'), findsOneWidget);
      expect(find.text('Buoy'), findsNothing);
    });
  });
}
