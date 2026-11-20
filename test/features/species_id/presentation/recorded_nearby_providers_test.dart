import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/species_id/data/repositories/dive_place_repository.dart';
import 'package:submersion/features/species_id/presentation/providers/dive_species_run_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../../media/presentation/support/media_widget_harness.dart';

/// Each dive's site and entry point, as the run's lean read reports them.
class _Places extends DivePlaceRepository {
  final places = <String, ({GeoPoint? site, GeoPoint? entry})>{};
  var reads = 0;
  Object? failure;

  @override
  Future<({bool exists, GeoPoint? site, GeoPoint? entry})> placeOf(
    String diveId,
  ) async {
    reads++;
    if (failure case final failure?) throw failure;
    final place = places[diveId];
    if (place == null) return (exists: false, site: null, entry: null);
    return (exists: true, site: place.site, entry: place.entry);
  }
}

/// The list a suggestion's marker reads (issue #4668).
void main() {
  const site = GeoPoint(12.1, -68.2);
  const otherSite = GeoPoint(12.5, -68.9);
  const photo = GeoPoint(12.2, -68.3);
  const entry = GeoPoint(12.3, -68.4);
  const listAtSite = NearbySpecies(speciesKeys: {2393681});
  const listAtOther = NearbySpecies(speciesKeys: {2393712});
  const listAtPhoto = NearbySpecies(speciesKeys: {2397321});

  late AppDatabase db;
  late _Places places;
  late List<GeoPoint> asked;
  late Map<GeoPoint, ReefPart<NearbySpecies>> parts;

  /// Lists still on their way, answered when a test completes them.
  late Map<GeoPoint, Completer<ReefPart<NearbySpecies>>> held;

  setUp(() async {
    db = await setUpTestDatabase();
    places = _Places();
    asked = [];
    held = {};
    parts = {
      site: const ReefPart.ok(listAtSite),
      otherSite: const ReefPart.ok(listAtOther),
      photo: const ReefPart.ok(listAtPhoto),
    };
  });
  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> container({
    List<Override> overrides = const [],
  }) async {
    final c = ProviderContainer(
      overrides: [
        ...await getBaseOverrides(),
        divePlaceRepositoryProvider.overrideWithValue(places),
        reefNearbySpeciesProvider.overrideWith((ref, point) async {
          asked.add(point);
          if (held[point] case final pending?) return pending.future;
          return parts[point] ?? const ReefPart.empty();
        }),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Completes once [request]'s list is [want]: a tick's refresh is
  /// waited for, not timed, so a slow machine cannot fail it.
  Future<void> shows(
    ProviderContainer c,
    NearbyListRequest request,
    NearbySpecies want,
  ) {
    final seen = Completer<void>();
    final sub = c.listen(recordedNearbyListProvider(request), (_, next) {
      if (next.value == want && !seen.isCompleted) seen.complete();
    });
    return seen.future
        .timeout(const Duration(seconds: 10))
        .whenComplete(sub.close);
  }

  test('reads the dive site\'s list, not the photo\'s position', () async {
    places.places['d1'] = (site: site, entry: entry);
    final c = await container();

    final list = await c.read(
      recordedNearbyListProvider((diveId: 'd1', photo: photo)).future,
    );

    expect(list, listAtSite);
    expect(asked, [site]);
  });

  test('without a site, the photo\'s position', () async {
    places.places['d1'] = (site: null, entry: entry);
    final c = await container();

    final list = await c.read(
      recordedNearbyListProvider((diveId: 'd1', photo: photo)).future,
    );

    expect(list, listAtPhoto);
    expect(asked, [photo]);
  });

  test('with no place it asks for nothing', () async {
    places.places['d1'] = (site: null, entry: null);
    final c = await container();

    final list = await c.read(
      recordedNearbyListProvider((diveId: 'd1', photo: null)).future,
    );

    expect(list, isNull);
    expect(asked, isEmpty);
  });

  test('a dive that is gone has no site and no entry', () async {
    final c = await container();

    final list = await c.read(
      recordedNearbyListProvider((diveId: 'gone', photo: null)).future,
    );

    expect(list, isNull);
    expect(asked, isEmpty);
  });

  test('an empty or unavailable list gives null', () async {
    places.places['d1'] = (site: site, entry: null);
    places.places['d2'] = (site: otherSite, entry: null);
    parts[site] = const ReefPart.empty();
    parts[otherSite] = const ReefPart.unavailable();
    final c = await container();

    expect(
      await c.read(
        recordedNearbyListProvider((diveId: 'd1', photo: null)).future,
      ),
      isNull,
    );
    expect(
      await c.read(
        recordedNearbyListProvider((diveId: 'd2', photo: null)).future,
      ),
      isNull,
    );
  });

  test('two dives at one site share one search', () async {
    places.places['d1'] = (site: site, entry: null);
    places.places['d2'] = (site: site, entry: entry);
    final c = await container();
    const first = (diveId: 'd1', photo: null);
    const second = (diveId: 'd2', photo: photo);

    // Two rows on screen hold both requests at once, so the shared list
    // stays alive between them.
    c.listen(recordedNearbyListProvider(first), (_, _) {});
    c.listen(recordedNearbyListProvider(second), (_, _) {});
    final lists = await Future.wait([
      c.read(recordedNearbyListProvider(first).future),
      c.read(recordedNearbyListProvider(second).future),
    ]);

    expect(lists, [listAtSite, listAtSite]);
    expect(asked, [site]);
  });

  test('a row shown later shares the search an earlier row made', () async {
    places.places['d1'] = (site: site, entry: null);
    places.places['d2'] = (site: site, entry: null);
    final c = await container();
    const first = (diveId: 'd1', photo: null);
    const second = (diveId: 'd2', photo: null);

    // The first row is on screen and has its list before the second row
    // scrolls into view.
    c.listen(recordedNearbyListProvider(first), (_, _) {});
    await c.read(recordedNearbyListProvider(first).future);
    // Time passes: anything nothing holds is disposed by now.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    c.listen(recordedNearbyListProvider(second), (_, _) {});
    await c.read(recordedNearbyListProvider(second).future);

    expect(asked, [site]);
  });

  group('a long review page', () {
    const thirdSite = GeoPoint(13.0, -69.0);
    const fourthSite = GeoPoint(13.5, -69.5);

    /// Four dives at four sites, each list held until completed, and
    /// each row's subscription, by dive.
    Future<(ProviderContainer, Map<String, ProviderSubscription<Object?>>)>
    fourRows() async {
      final sites = [site, otherSite, thirdSite, fourthSite];
      for (var i = 0; i < sites.length; i++) {
        places.places['d${i + 1}'] = (site: sites[i], entry: null);
        held[sites[i]] = Completer();
      }
      final c = await container();
      final rows = {
        for (var i = 1; i <= sites.length; i++)
          'd$i': c.listen(
            recordedNearbyListProvider((diveId: 'd$i', photo: null)),
            (_, _) {},
          ),
      };
      await pumpEventQueue();
      return (c, rows);
    }

    test('asks GBIF for at most two lists at once', () async {
      await fourRows();
      expect(asked, [site, otherSite]);

      held[site]!.complete(const ReefPart.ok(listAtSite));
      await pumpEventQueue();
      expect(asked, [site, otherSite, thirdSite]);
    });

    test('a row that leaves while waiting gives up its turn', () async {
      final (_, rows) = await fourRows();
      rows['d3']!.close();
      await pumpEventQueue();

      held[site]!.complete(const ReefPart.ok(listAtSite));
      await pumpEventQueue();
      expect(asked, [site, otherSite, fourthSite]);
    });

    test(
      'a row that leaves while its list is on the way frees its turn',
      () async {
        final (_, rows) = await fourRows();
        rows['d1']!.close();
        await pumpEventQueue();

        expect(asked, [site, otherSite, thirdSite]);
      },
    );
    test('a row whose list is already on its way does not wait for a '
        'turn', () async {
      final (c, _) = await fourRows();
      // A fifth dive at the first site, whose list d1 is fetching now,
      // while d3 and d4 wait their turns.
      places.places['d5'] = (site: site, entry: null);
      const fifth = (diveId: 'd5', photo: null);
      c.listen(recordedNearbyListProvider(fifth), (_, _) {});
      await pumpEventQueue();

      held[site]!.complete(const ReefPart.ok(listAtSite));
      await pumpEventQueue();

      expect(c.read(recordedNearbyListProvider(fifth)).value, listAtSite);
      expect(asked, [site, otherSite, thirdSite]);
    });
  });

  test('a row whose turn comes once its list is on its way hands the turn '
      'on', () async {
    const fifthSite = GeoPoint(14.0, -70.0);
    const thirdSite = GeoPoint(13.0, -69.0);
    // d1 and d2 take the two turns; d5 and d6 (both at the fifth site) and
    // then d3 wait, in that order.
    for (final (dive, at) in [
      ('d1', site),
      ('d2', otherSite),
      ('d5', fifthSite),
      ('d6', fifthSite),
      ('d3', thirdSite),
    ]) {
      places.places[dive] = (site: at, entry: null);
    }
    for (final at in [site, otherSite, fifthSite, thirdSite]) {
      held[at] = Completer();
    }
    final c = await container();
    for (final dive in ['d1', 'd2', 'd5', 'd6', 'd3']) {
      c.listen(
        recordedNearbyListProvider((diveId: dive, photo: null)),
        (_, _) {},
      );
      await pumpEventQueue();
    }
    expect(asked, [site, otherSite]);

    held[site]!.complete(const ReefPart.ok(listAtSite));
    await pumpEventQueue();
    expect(asked, [site, otherSite, fifthSite]);

    // d6's turn: its list is already on its way for d5, so the turn goes
    // straight on to d3 rather than waiting on d5's fetch.
    held[otherSite]!.complete(const ReefPart.ok(listAtOther));
    await pumpEventQueue();
    expect(asked, [site, otherSite, fifthSite, thirdSite]);
  });

  test('photos a few metres apart share one list', () async {
    final c = await container();
    const near = GeoPoint(12.20012, -68.30011);
    const nearer = GeoPoint(12.20018, -68.30016);

    await Future.wait([
      c.read(recordedNearbyListProvider((diveId: null, photo: near)).future),
      c.read(recordedNearbyListProvider((diveId: null, photo: nearer)).future),
    ]);

    expect(asked, [photo]);
  });

  test('a photo in no dive uses its own position', () async {
    final c = await container();

    final list = await c.read(
      recordedNearbyListProvider((diveId: null, photo: photo)).future,
    );

    expect(list, listAtPhoto);
    expect(asked, [photo]);
  });

  test('a photo in no dive reads nothing of the logbook', () async {
    // Where no logbook is open, as under a video's labels in a widget test.
    final c = await container(
      overrides: [
        diveRepositoryProvider.overrideWith(
          (ref) => throw StateError('no logbook'),
        ),
        siteRepositoryProvider.overrideWith(
          (ref) => throw StateError('no logbook'),
        ),
      ],
    );

    final list = await c.read(
      recordedNearbyListProvider((diveId: null, photo: photo)).future,
    );

    expect(list, listAtPhoto);
    expect(places.reads, 0);
  });

  test('a list that cannot be read is not asked for again', () async {
    places.failure = Exception('database closed');
    final c = await container();
    const request = (diveId: 'd1', photo: null);
    c.listen(recordedNearbyListProvider(request), (_, _) {});

    await expectLater(
      c.read(recordedNearbyListProvider(request).future),
      throwsException,
    );
    // Past the first automatic retry, were there one.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(places.reads, 1);
    expect(c.read(recordedNearbyListProvider(request)).value, isNull);
  });

  test('a dive moved to another site reads that site\'s list', () async {
    places.places['d1'] = (site: site, entry: null);
    final c = await container();
    const request = (diveId: 'd1', photo: null);
    c.listen(recordedNearbyListProvider(request), (_, _) {});
    expect(
      await c.read(recordedNearbyListProvider(request).future),
      listAtSite,
    );

    final moved = shows(c, request, listAtOther);
    places.places['d1'] = (site: otherSite, entry: null);
    db.markTablesUpdated([db.dives]);

    await moved;
  });

  test('a site moved on the map reads the new point\'s list', () async {
    places.places['d1'] = (site: site, entry: null);
    final c = await container();
    const request = (diveId: 'd1', photo: null);
    c.listen(recordedNearbyListProvider(request), (_, _) {});
    expect(
      await c.read(recordedNearbyListProvider(request).future),
      listAtSite,
    );

    final moved = shows(c, request, listAtOther);
    places.places['d1'] = (site: otherSite, entry: null);
    db.markTablesUpdated([db.diveSites]);

    await moved;
  });

  group('nearbyRequestForMedia', () {
    test('a photo with GPS carries its position', () {
      final item = testMediaItem(
        id: 'p1',
        diveId: 'd1',
      ).copyWith(latitude: 12.2, longitude: -68.3);
      expect(nearbyRequestForMedia(item), (diveId: 'd1', photo: photo));
    });

    test('a photo without both coordinates carries none', () {
      final item = testMediaItem(id: 'p1').copyWith(latitude: 12.2);
      expect(nearbyRequestForMedia(item), (diveId: null, photo: null));
    });
  });
}
