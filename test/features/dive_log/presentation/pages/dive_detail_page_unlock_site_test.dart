import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_sitting_follow_up.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_hero_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_area_anchor_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/site_area_anchor.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/test_database.dart';
import '../support/fake_matching_service.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The dive's site in a sitting, through the page: the picker the site row
/// opens, a location the suggestion adds, the species the save refreshes,
/// the hero's link to the site, and a site picked back (issue #4527, plan
/// 4).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  RecordEditController<Dive> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Dive>(
        tester.element(find.byType(DiveDetailHeroSection)),
      )!;

  Future<void> openHeader(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Edit Dive'));
    await settle(tester);
  }

  SitePickerSheet sheet(WidgetTester tester) =>
      tester.widget<SitePickerSheet>(find.byType(SitePickerSheet));

  Future<void> closeSheet(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(SitePickerSheet))).pop();
    await settle(tester);
  }

  group('the site picker', () {
    testWidgets('opens on the dive\'s own GPS, with no area looked up', (
      tester,
    ) async {
      // A dive with GPS has a map in its hero: the tile server answers 404
      // at once, as it would with no network.
      serveFakeHost('tile.openstreetmap.org', const FakeResponse(404));
      const gps = GeoPoint(20.5, -87.25);
      final anchors = _Anchors();
      await pumpPage(
        tester,
        stored: dive.copyWith(entryLocation: gps),
        extra: [siteAreaAnchorRepositoryProvider.overrideWithValue(anchors)],
      );
      await unlock(tester);
      await openHeader(tester);

      await tester.tap(find.text('Add site'));
      await settle(tester);

      expect(find.byType(SitePickerSheet), findsOneWidget);
      expect(sheet(tester).diveLocation, gps);
      expect(sheet(tester).areaAnchor, isNull);
      expect(anchors.asked, isEmpty);
    });

    testWidgets('lacking GPS, opens on the area of the dives around it, '
        'one sheet for each tap', (tester) async {
      const area = SiteAreaAnchor(
        point: GeoPoint(-8.5, 115.5),
        placeLabel: 'Bali',
      );
      final anchors = _Anchors(Completer<SiteAreaAnchor?>());
      await pumpPage(
        tester,
        stored: dive.copyWith(diverId: 'diver-1', tripId: 'trip-1'),
        extra: [siteAreaAnchorRepositoryProvider.overrideWithValue(anchors)],
      );
      await unlock(tester);
      await openHeader(tester);

      // A second tap while the area is still being worked out opens
      // nothing more.
      await tester.tap(find.text('Add site'));
      await tester.pump();
      await tester.tap(find.text('Add site'));
      await tester.pump();
      anchors.answer!.complete(area);
      await settle(tester);

      expect(find.byType(SitePickerSheet), findsOneWidget);
      expect(sheet(tester).areaAnchor, area);
      expect(sheet(tester).diveLocation, isNull);
      expect(anchors.asked, hasLength(1));
      final asked = anchors.asked.single;
      expect(asked.at, dive.effectiveEntryTime);
      expect(asked.tripId, 'trip-1');
      expect(asked.diverId, 'diver-1');
      expect(asked.excludeDiveIds, [dive.id]);

      // Closed, the row opens it again on the next tap.
      await closeSheet(tester);
      expect(find.byType(SitePickerSheet), findsNothing);
      await tester.tap(find.text('Add site'));
      await settle(tester);

      expect(find.byType(SitePickerSheet), findsOneWidget);
      expect(anchors.asked, hasLength(2));
    });
  });

  testWidgets('a location the suggestion adds is written to the site by '
      'Save, and not before', (tester) async {
    const bare = DiveSite(id: 'bare', name: 'Typed Twice');
    final service = FakeMatchingService();
    final sites = _SpySiteRepository();
    final altitudesLookedUp = <(String, GeoPoint)>[];
    SpySites? siteList;
    final page = await pumpPage(
      tester,
      stored: dive.copyWith(site: bare),
      extra: [
        siteRepositoryProvider.overrideWithValue(sites),
        diveSiteAltitudeFillProvider.overrideWithValue(
          (siteId, point) async => altitudesLookedUp.add((siteId, point)),
        ),
        siteListNotifierProvider.overrideWith(
          (ref) => siteList = SpySites(ref.watch(siteRepositoryProvider), ref),
        ),
        siteSuggestionForDiveProvider(
          dive.id,
        ).overrideWith((ref) async => suggestionFor(service, site: bare)),
      ],
    );
    await unlock(tester);

    await tester.tap(find.textContaining('Add location to Typed Twice'));
    await settle(tester);
    expect(sites.coordinates, isEmpty);
    expect(action(tester, 'Save').onPressed, isNotNull);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(sites.coordinates, [('bare', const GeoPoint(20.5, -87.25))]);
    // The site had no altitude: the held write noted it during the save,
    // and the follow-up after the commit looks it up (Copilot's review of
    // PR #4670 read the note as cleared before the save could make it).
    expect(altitudesLookedUp, [('bare', const GeoPoint(20.5, -87.25))]);
    expect(page.save.calls.single.cards, [diveHeaderCardId]);
    expect(page.save.heldChangeFlags.single, isTrue);
    expect(siteList?.refreshes, 1);
    // The dive itself keeps its site; only the site gained a location.
    expect(page.save.stored.site?.id, 'bare');
  });

  // The save refreshes what the two sites have seen by invalidating their
  // species, which cannot throw itself; what can fail is the read that
  // follows. A failure there stays with the species and is no failed save.
  testWidgets('a species refresh that throws is not a failed save', (
    tester,
  ) async {
    const old = DiveSite(id: 'old', name: 'Old');
    const reef = DiveSite(id: 'reef', name: 'Reef');
    final reads = <String, int>{};
    final page = await pumpPage(
      tester,
      stored: dive.copyWith(site: old),
      extra: [
        for (final id in ['old', 'reef'])
          siteSpottedSpeciesProvider(id).overrideWith((ref) async {
            final read = reads[id] = (reads[id] ?? 0) + 1;
            if (read > 1) throw StateError('species unreadable');
            return const [];
          }),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailHeroSection)),
    );
    for (final id in ['old', 'reef']) {
      final sub = container.listen(siteSpottedSpeciesProvider(id), (_, _) {});
      addTearDown(sub.close);
    }
    await settle(tester);
    await unlock(tester);
    readDiveSiteAssigner(tester.element(find.byType(DiveDetailHeroSection)))(
      controllerOf(tester).session!,
      reef,
    );
    await settle(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(reads, {'old': 2, 'reef': 2});
    expect(container.read(siteSpottedSpeciesProvider('reef')).hasError, isTrue);
    expect(page.save.calls, hasLength(1));
    expect(page.save.stored.site?.id, 'reef');
    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsNothing,
    );
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
  });

  testWidgets('a tap on the hero opens the site while unlocked, and the '
      'sitting is there on the way back', (tester) async {
    // The hero is a link only over its map, which asks for tiles: the tile
    // server answers 404 at once, as it would with no network.
    serveFakeHost('tile.openstreetmap.org', const FakeResponse(404));
    const reef = DiveSite(
      id: 'reef',
      name: 'Blue Corner',
      location: GeoPoint(7.1, 134.2),
    );
    final page = await pumpPage(
      tester,
      stored: dive.copyWith(site: reef),
      routes: [
        GoRoute(
          path: '/sites/:id',
          builder: (context, state) =>
              Scaffold(body: Text('SITE ${state.pathParameters['id']}')),
        ),
      ],
    );
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(find.byType(TextField).first, 'Choppy');
    await settle(tester);
    final before = controllerOf(tester).session;

    final link = find.ancestor(
      of: find.byType(DiveLocationsMap),
      matching: find.byWidgetPredicate((w) => w is InkWell && w.onTap != null),
    );
    expect(link, findsOneWidget);
    await tester.tap(find.text('Blue Corner').first);
    await settle(tester);

    expect(find.text('SITE reef'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);

    page.router.pop();
    await settle(tester);

    expect(location(page.router), '/home/dive');
    expect(controllerOf(tester).session, same(before));
    expect(action(tester, 'Save').onPressed, isNotNull);
  });

  testWidgets('the stored site picked back after two others leaves the '
      'sitting clean', (tester) async {
    const home = DiveSite(
      id: 'home',
      name: 'Home Reef',
      entryMethods: [EntryMethod.shore],
    );
    const wreck = DiveSite(
      id: 'wreck',
      name: 'Wreck Bay',
      waterType: WaterType.salt,
      entryMethods: [EntryMethod.boat],
      location: GeoPoint(46, 8),
    );
    const quarry = DiveSite(
      id: 'quarry',
      name: 'Quarry',
      waterType: WaterType.brackish,
      entryMethods: [EntryMethod.giantStride],
      location: GeoPoint(47, 9),
    );
    // The two others have a location, so the hero shows a map while they
    // are on the dive.
    serveFakeHost('tile.openstreetmap.org', const FakeResponse(404));
    final elevation = _Elevation({46: 512, 47: 1300});
    final stored = dive.copyWith(
      site: home,
      waterType: WaterType.fresh,
      entryMethod: EntryMethod.shore,
      exitMethod: EntryMethod.shore,
    );
    final page = await pumpPage(
      tester,
      stored: stored,
      extra: [elevationServiceProvider.overrideWithValue(elevation)],
    );
    await unlock(tester);
    final session = controllerOf(tester).session!;
    final heldAtStart = session.heldKeys;
    final assign = readDiveSiteAssigner(
      tester.element(find.byType(DiveDetailHeroSection)),
    );

    // Each of the two others sets its own values, and its looked-up
    // altitude is held for its site.
    assign(session, wreck);
    await settle(tester);
    expect(session.working.waterType, WaterType.salt);
    expect(session.working.altitude, 512);
    assign(session, quarry);
    await settle(tester);
    expect(session.working.waterType, WaterType.brackish);
    expect(session.working.entryMethod, EntryMethod.giantStride);
    expect(session.working.altitude, 1300);
    expect(session.heldKeys, contains(siteAltitudeWriteKey('quarry')));
    expect(session.isDirty, isTrue);

    assign(session, home);
    await settle(tester);

    expect(elevation.calls, 2);
    expect(session.working.site?.id, 'home');
    expect(session.working.waterType, WaterType.fresh);
    expect(session.working.entryMethod, EntryMethod.shore);
    expect(session.working.exitMethod, EntryMethod.shore);
    expect(session.working.altitude, isNull);
    // Only what the sitting held from its start: neither site's altitude
    // write is left.
    expect(session.heldKeys, heldAtStart);
    expect(session.isDirty, isFalse);
    expect(action(tester, 'Save').onPressed, isNull);
    expect(page.save.calls, isEmpty);
  });
}

/// An area lookup that records what it was asked, and answers when the
/// test says (at once, with nothing, when no [answer] is given).
class _Anchors extends SiteAreaAnchorRepository {
  _Anchors([this.answer]);

  final Completer<SiteAreaAnchor?>? answer;
  final asked =
      <
        ({
          DateTime at,
          String? tripId,
          String? diverId,
          List<String> excludeDiveIds,
        })
      >[];

  @override
  Future<SiteAreaAnchor?> forDive({
    required DateTime at,
    String? tripId,
    String? diverId,
    List<String> excludeDiveIds = const [],
  }) async {
    asked.add((
      at: at,
      tripId: tripId,
      diverId: diverId,
      excludeDiveIds: excludeDiveIds,
    ));
    return answer?.future;
  }
}

/// Records the coordinates written to a site instead of writing them.
class _SpySiteRepository extends SiteRepository {
  final coordinates = <(String, GeoPoint)>[];

  @override
  Future<void> updateSiteCoordinates(
    String siteId,
    GeoPoint location, {
    double? altitude,
  }) async => coordinates.add((siteId, location));

  /// A site as the written coordinates left it, as the held write reads it
  /// back.
  @override
  Future<DiveSite?> getSiteById(String id) async {
    final written = coordinates.where((c) => c.$1 == id);
    return DiveSite(
      id: id,
      name: id,
      location: written.isEmpty ? null : written.last.$2,
    );
  }
}

/// Answers elevation lookups by latitude, and counts them.
class _Elevation extends ElevationService {
  _Elevation(this.byLatitude)
    : super(client: MockClient((_) async => http.Response('', 500)));

  final Map<double, double?> byLatitude;
  int calls = 0;

  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    return byLatitude[latitude];
  }
}
