import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/compact_buddy_list_tile.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_list_content.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_card.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_tile.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/global_search/presentation/widgets/global_search_rows.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/seen_species_tile.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_catalog_tile.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_list_row.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/compact_trip_list_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late SharedPreferences _prefs;
final _now = DateTime(2026, 10, 30);

const _site = DiveSite(id: 'x', name: 'Salt Pier');
final _trip = Trip(
  id: 'x',
  name: 'Bonaire',
  startDate: _now,
  endDate: _now,
  createdAt: _now,
  updatedAt: _now,
);
const _species = Species(
  id: 'x',
  commonName: 'Whale Shark',
  category: SpeciesCategory.shark,
);
final _document = Document(
  id: 'x',
  diverId: 'me',
  owner: const DocumentOwner.personal(),
  type: DocumentType.insurance,
  title: 'DAN',
  createdAt: _now,
  updatedAt: _now,
);

Widget _host(
  GlobalSearchKind kind, {
  List<String> ids = const ['x'],
  ValueChanged<String>? onOpen,
  List<SeenSpecies> seen = const [],
  List<DocumentListEntry>? documents,
  List<Diver> divers = const [],
  Set<String> sharedSites = const {},
  Future<List<BuddyWithDiveCount>> Function()? buddies,
  List<EquipmentItem> equipment = const [
    EquipmentItem(id: 'x', name: 'Primary', type: EquipmentType.regulator),
  ],
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(_prefs),
    settingsProvider.overrideWith((ref) => _StubSettings()),
    certificationCatalogSyncProvider.overrideWithValue(
      CertificationCatalog.builtInOnly,
    ),
    allDiversProvider.overrideWith((ref) async => divers),
    itemIdsWithSharesProvider.overrideWith(
      (ref, kind) async =>
          kind == SharedItemKind.site ? sharedSites : const <String>{},
    ),
    globalSearchDivesProvider.overrideWith(
      (ref, key) async => [
        DiveSummary(
          id: 'x',
          dateTime: _now,
          maxDepth: 30,
          diveNumber: 12,
          sortTimestamp: _now.millisecondsSinceEpoch,
        ),
      ],
    ),
    sitesWithCountsProvider.overrideWith(
      (ref) async => [const SiteWithDiveCount(site: _site, diveCount: 4)],
    ),
    allTripsWithStatsProvider.overrideWith(
      (ref) async => [TripWithStats(trip: _trip, diveCount: 3)],
    ),
    allEquipmentProvider.overrideWith((ref) async => equipment),
    equipmentSetsProvider.overrideWith(
      (ref) async => [
        EquipmentSet(id: 'x', name: 'Cold', createdAt: _now, updatedAt: _now),
      ],
    ),
    allBuddiesWithDiveCountProvider.overrideWith(
      (ref) =>
          buddies?.call() ??
          [
            BuddyWithDiveCount(
              buddy: Buddy(
                id: 'x',
                name: 'Robin',
                createdAt: _now,
                updatedAt: _now,
              ),
              diveCount: 2,
            ),
          ],
    ),
    allDiveCentersProvider.overrideWith(
      (ref) async => [
        DiveCenter(id: 'x', name: 'Reef', createdAt: _now, updatedAt: _now),
      ],
    ),
    diveCenterDiveCountProvider.overrideWith((ref, id) async => 5),
    allCertificationsProvider.overrideWith(
      (ref) async => [
        Certification(
          id: 'x',
          name: 'Rescue',
          agency: 'padi',
          createdAt: _now,
          updatedAt: _now,
        ),
      ],
    ),
    allCoursesProvider.overrideWith(
      (ref) async => [
        Course(
          id: 'x',
          diverId: 'me',
          name: 'Ecology',
          agency: 'padi',
          startDate: _now,
          createdAt: _now,
          updatedAt: _now,
        ),
      ],
    ),
    allSpeciesProvider.overrideWith((ref) async => [_species]),
    seenSpeciesProvider.overrideWith((ref) async => seen),
    speciesCoverMediaProvider.overrideWith((ref) async => const {}),
    allDocumentsProvider.overrideWith(
      (ref) async => documents ?? [DocumentListEntry(_document, null, 0)],
    ),
    tagsByItemProvider.overrideWith(
      (ref, scope) async => const <String, List<Tag>>{},
    ),
    divePlanSummariesProvider.overrideWith(
      (ref) async => [
        DivePlanSummary(id: 'x', name: 'Deep', updatedAt: _now, maxDepth: 45),
      ],
    ),
    gpsTracksProvider.overrideWith(
      (ref) async => const [GpsTrack(id: 'x', startTime: 1000, endTime: 2000)],
    ),
    allNavTracksProvider.overrideWith(
      (ref) async => [
        NavTrack(
          id: 'x',
          source: NavTrackSource.seacraftEnc,
          startTime: 1000,
          endTime: 2000,
          pointCount: 0,
          createdAt: _now,
          updatedAt: _now,
        ),
      ],
    ),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: GlobalSearchRows(kind: kind, ids: ids, onOpen: onOpen ?? (_) {}),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  final tiles = <GlobalSearchKind, Type>{
    GlobalSearchKind.dives: CompactDiveListTile,
    GlobalSearchKind.sites: CompactSiteListTile,
    GlobalSearchKind.trips: CompactTripListTile,
    GlobalSearchKind.equipment: EquipmentListTile,
    GlobalSearchKind.equipmentSets: EquipmentSetTile,
    GlobalSearchKind.buddies: CompactBuddyListTile,
    GlobalSearchKind.diveCenters: CompactDiveCenterListTile,
    GlobalSearchKind.certifications: CertificationListTile,
    GlobalSearchKind.courses: CourseCard,
    GlobalSearchKind.species: SpeciesCatalogTile,
    GlobalSearchKind.documents: DocumentTile,
    GlobalSearchKind.divePlans: SavedPlanTile,
    GlobalSearchKind.gpsTracks: GpsTrackListTile,
    GlobalSearchKind.underwaterRoutes: NavTrackListRow,
  };

  test('every kind has a row to check', () {
    expect(tiles.keys.toSet(), GlobalSearchKind.values.toSet());
  });

  for (final MapEntry(key: kind, value: tile) in tiles.entries) {
    testWidgets('$kind draws its own list\'s row and opens it', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(_host(kind, onOpen: opened.add));
      await tester.pump();
      await tester.pump();

      expect(find.byType(tile), findsOneWidget);
      await tester.tap(find.byType(tile));
      expect(opened, ['x']);
    });
  }

  testWidgets('identical gear is told apart as the Equipment list does', (
    tester,
  ) async {
    EquipmentItem pouch(String id, String serial) => EquipmentItem(
      id: id,
      name: 'Pouches',
      type: EquipmentType.other,
      brand: 'Palantic',
      model: 'Drop-Bottom',
      serialNumber: serial,
    );
    await tester.pumpWidget(
      _host(
        GlobalSearchKind.equipment,
        ids: const ['a', 'b'],
        equipment: [pouch('a', 'X1'), pouch('b', 'X2')],
      ),
    );
    await tester.pump();
    await tester.pump();

    // Labelled as one list (#1549): the serial that differs is shown.
    expect(find.text('Palantic Drop-Bottom · S/N X1'), findsOneWidget);
    expect(find.text('Palantic Drop-Bottom · S/N X2'), findsOneWidget);
  });

  testWidgets('a logged species reads as the logbook does', (tester) async {
    await tester.pumpWidget(
      _host(
        GlobalSearchKind.species,
        seen: [
          SeenSpecies(
            species: _species,
            totalSightings: 3,
            diveCount: 2,
            siteCount: 1,
            firstSeen: _now,
            lastSeen: _now,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SeenSpeciesTile), findsOneWidget);
    expect(find.byType(SpeciesCatalogTile), findsNothing);
  });

  testWidgets('a document names the certification it is filed under', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        GlobalSearchKind.documents,
        documents: [
          DocumentListEntry(
            _document,
            '',
            0,
            certification: (name: 'Rescue Diver', agency: 'padi', level: null),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Rescue Diver'), findsOneWidget);
  });

  testWidgets('keeps the order the search found them in', (tester) async {
    await tester.pumpWidget(
      _host(
        GlobalSearchKind.buddies,
        ids: const ['b', 'a'],
        buddies: () async => [
          for (final id in const ['a', 'b'])
            BuddyWithDiveCount(
              buddy: Buddy(
                id: id,
                name: 'Buddy $id',
                createdAt: _now,
                updatedAt: _now,
              ),
              diveCount: 0,
            ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Buddy b')).dy,
      lessThan(tester.getTopLeft(find.text('Buddy a')).dy),
    );
  });

  testWidgets('leaves out a record that has just gone', (tester) async {
    await tester.pumpWidget(
      _host(GlobalSearchKind.sites, ids: const ['x', 'gone']),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CompactSiteListTile), findsOneWidget);
  });

  testWidgets('shows the shared badge a household would see', (tester) async {
    await tester.pumpWidget(
      _host(
        GlobalSearchKind.sites,
        divers: [
          Diver(id: 'a', name: 'A', createdAt: _now, updatedAt: _now),
          Diver(id: 'b', name: 'B', createdAt: _now, updatedAt: _now),
        ],
        sharedSites: const {'x'},
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<CompactSiteListTile>(find.byType(CompactSiteListTile))
          .showSharedBadge,
      isTrue,
    );
  });

  testWidgets('holds their place while the records load', (tester) async {
    await tester.pumpWidget(
      _host(
        GlobalSearchKind.buddies,
        ids: const ['a', 'b'],
        buddies: () => Future.delayed(const Duration(days: 1), () => const []),
      ),
    );

    expect(find.byType(CompactBuddyListTile), findsNothing);
    expect(tester.getSize(find.byType(GlobalSearchRows)).height, 144);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(days: 2));
  });

  testWidgets('says so when the records fail to load', (tester) async {
    await tester.pumpWidget(
      _host(
        GlobalSearchKind.buddies,
        buddies: () async => throw StateError('boom'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Search failed. Please try again.'), findsOneWidget);
  });
}
