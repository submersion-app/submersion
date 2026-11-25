import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/domain/services/site_lookup_memory.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

/// Answers each coordinate from a map; unknown coordinates come back empty.
class _MapLocationService implements LocationService {
  _MapLocationService(this.answers, {this.offline = false, this.throwOn});

  final Map<String, PlaceLookup> answers;
  final bool offline;
  final String? throwOn;
  final List<String> asked = [];

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    final key = '$latitude,$longitude';
    asked.add(key);
    if (offline) return const PlaceLookup.unavailable();
    if (key == throwOn) throw StateError('boom');
    return answers[key] ?? const PlaceLookup.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Runs [onFirstLookup] during the first lookup, to model an edit that
/// lands while a request is in flight.
class _MovingLocationService extends _MapLocationService {
  _MovingLocationService(super.answers, this.onFirstLookup);

  final Future<void> Function() onFirstLookup;
  var _moved = false;

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    if (!_moved) {
      _moved = true;
      await onFirstLookup();
    }
    return super.reverseGeocode(
      latitude,
      longitude,
      languageCode: languageCode,
    );
  }
}

/// Holds notes in memory and counts writes.
class _FakeMemory implements SiteLookupMemory {
  Map<String, SiteLookupNote> notes = {};
  int writes = 0;

  @override
  Future<Map<String, SiteLookupNote>> read() async => Map.of(notes);

  @override
  Future<void> write(Map<String, SiteLookupNote> next) async {
    writes++;
    notes = Map.of(next);
  }
}

void main() {
  late SiteRepository sites;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const weggis = PlaceLookup(
    country: 'Switzerland',
    region: 'Lucerne',
    locality: 'Weggis',
    bodyOfWater: 'Lake Lucerne',
  );

  Future<void> seed() async {
    await sites.createSite(
      const DiveSite(id: 'empty', name: 'Empty', location: GeoPoint(47.0, 8.4)),
    );
    await sites.createSite(
      const DiveSite(
        id: 'partial',
        name: 'Partial',
        country: 'Switzerland',
        region: 'Lucerne',
        location: GeoPoint(47.1, 8.5),
      ),
    );
    await sites.createSite(
      const DiveSite(
        id: 'full',
        name: 'Full',
        country: 'a',
        region: 'b',
        city: 'c',
        bodyOfWater: 'd',
        location: GeoPoint(47.2, 8.6),
      ),
    );
    await sites.createSite(const DiveSite(id: 'nogps', name: 'No GPS'));
  }

  SiteLocationBackfillService service(
    LocationService location, {
    SiteLocationLookupMode mode = SiteLocationLookupMode.fillMissing,
    SiteLookupMemory? memory,
  }) => SiteLocationBackfillService(
    sites: sites,
    location: location,
    languageCode: 'en',
    mode: mode,
    memory: memory,
  );

  test('needsLookup wants coordinates and at least one empty field', () {
    expect(
      SiteLocationBackfillService.needsLookup(
        const DiveSite(id: '1', name: 'n', location: GeoPoint(1, 2)),
      ),
      isTrue,
    );
    expect(
      SiteLocationBackfillService.needsLookup(
        const DiveSite(id: '1', name: 'n'),
      ),
      isFalse,
    );
    expect(
      SiteLocationBackfillService.needsLookup(
        const DiveSite(
          id: '1',
          name: 'n',
          location: GeoPoint(1, 2),
          country: 'a',
          region: 'b',
          city: 'c',
          bodyOfWater: 'd',
        ),
      ),
      isFalse,
    );
    expect(
      SiteLocationBackfillService.needsLookup(
        const DiveSite(
          id: '1',
          name: 'n',
          location: GeoPoint(1, 2),
          country: 'a',
          region: 'b',
          city: '  ',
          bodyOfWater: 'd',
        ),
      ),
      isTrue,
      reason: 'blank counts as empty',
    );
  });

  test('candidates skips full sites and sites without coordinates', () async {
    await seed();
    final found = await service(_MapLocationService({})).candidates();
    expect(found.sites.map((s) => s.id), unorderedEquals(['empty', 'partial']));
    expect(found.alreadyLookedUp, 0);
  });

  test('a library site this profile only reads is not looked up', () async {
    await seed();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await SharedLibraryStore().upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'acc',
        prefix: 'site-sync',
        roles: SharedLibraryRoles(owners: {'o'}),
      ),
    );
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    );
    await sites.createSite(
      const DiveSite(
        id: 'shared',
        name: 'Shared',
        sharedLibraryId: 'L',
        location: GeoPoint(47.3, 8.7),
      ),
    );
    final found = await service(_MapLocationService({})).candidates();
    expect(found.sites.map((s) => s.id), unorderedEquals(['empty', 'partial']));
    expect(found.alreadyLookedUp, 0);
  });

  test('run fills only empty fields and counts outcomes', () async {
    await seed();
    final location = _MapLocationService({
      '47.0,8.4': weggis,
      '47.1,8.5': const PlaceLookup(country: 'Schweiz', locality: 'Weggis'),
    });
    final progress = <(int, int)>[];

    final summary = await service(location).run(
      onProgress: (done, total) => progress.add((done, total)),
      isCancelled: () => false,
    );

    expect(summary.total, 2);
    expect(summary.updated, 2);
    expect(summary.unchanged, 0);
    expect(summary.failed, 0);
    expect(summary.cancelled, isFalse);
    expect(progress, [(0, 2), (1, 2), (2, 2)]);
    expect(location.asked, hasLength(2), reason: 'full and nogps not asked');

    final partial = await sites.getSiteById('partial');
    expect(partial!.country, 'Switzerland', reason: 'kept');
    expect(partial.city, 'Weggis');
    final empty = await sites.getSiteById('empty');
    expect(empty!.bodyOfWater, 'Lake Lucerne');
  });

  test('run uses the targets it is given instead of listing again', () async {
    await seed();
    final location = _MapLocationService({'47.2,8.6': weggis});
    final full = (await sites.getSiteById('full'))!;

    final summary = await service(
      location,
    ).run(targets: [full], onProgress: (_, _) {}, isCancelled: () => false);

    expect(summary.total, 1);
    // A candidate scan would have taken the two incomplete sites instead.
    expect(location.asked, ['47.2,8.6']);
  });

  test('a lookup that finds nothing counts as unchanged', () async {
    await seed();
    final summary = await service(
      _MapLocationService({}),
    ).run(onProgress: (_, _) {}, isCancelled: () => false);
    expect(summary.updated, 0);
    expect(summary.unchanged, 2);
  });

  test('a throwing site is counted as failed and the run continues', () async {
    await seed();
    final location = _MapLocationService({
      '47.1,8.5': weggis,
    }, throwOn: '47.0,8.4');

    final summary = await service(
      location,
    ).run(onProgress: (_, _) {}, isCancelled: () => false);

    expect(summary.failed, 1);
    expect(summary.updated, 1);
  });

  test('cancelling between sites stops the run', () async {
    await seed();
    final location = _MapLocationService({'47.0,8.4': weggis});
    var calls = 0;

    final summary = await service(
      location,
    ).run(onProgress: (_, _) {}, isCancelled: () => calls++ >= 1);

    expect(summary.cancelled, isTrue);
    expect(location.asked, hasLength(1));
  });

  test('an unreachable geocoder on the first site aborts as offline', () async {
    await seed();
    final location = _MapLocationService({}, offline: true);

    final summary = await service(
      location,
    ).run(onProgress: (_, _) {}, isCancelled: () => false);

    expect(summary.offline, isTrue);
    expect(summary.failed, 0);
    expect(location.asked, hasLength(1));
  });

  group('refreshAll', () {
    test('wants every site with coordinates, however complete', () async {
      await seed();
      final found = await service(
        _MapLocationService({}),
        mode: SiteLocationLookupMode.refreshAll,
      ).candidates();
      expect(
        found.sites.map((s) => s.id),
        unorderedEquals(['empty', 'partial', 'full']),
        reason: 'only the site without coordinates is skipped',
      );
    });

    test('rewrites values geocoded in another language', () async {
      await sites.createSite(
        const DiveSite(
          id: 'de',
          name: 'Hertenstein',
          country: 'Schweiz',
          region: 'Luzern',
          city: 'Weggis',
          bodyOfWater: 'Vierwaldstattersee',
          location: GeoPoint(47.0, 8.4),
        ),
      );
      final location = _MapLocationService({'47.0,8.4': weggis});

      final summary = await service(
        location,
        mode: SiteLocationLookupMode.refreshAll,
      ).run(onProgress: (_, _) {}, isCancelled: () => false);

      expect(summary.updated, 1);
      final stored = await sites.getSiteById('de');
      expect(stored!.country, 'Switzerland');
      expect(stored.region, 'Lucerne');
      expect(stored.bodyOfWater, 'Lake Lucerne');
    });

    test('a site already in the language counts as unchanged', () async {
      await sites.createSite(
        const DiveSite(
          id: 'en',
          name: 'Hertenstein',
          country: 'Switzerland',
          countryCode: 'CH',
          region: 'Lucerne',
          city: 'Weggis',
          bodyOfWater: 'Lake Lucerne',
          location: GeoPoint(47.0, 8.4),
        ),
      );

      final summary = await service(
        _MapLocationService({'47.0,8.4': weggis}),
        mode: SiteLocationLookupMode.refreshAll,
      ).run(onProgress: (_, _) {}, isCancelled: () => false);

      expect(summary.updated, 0);
      expect(summary.unchanged, 1);
    });

    test(
      'a site missing only its country code gains it (issue #4426)',
      () async {
        await sites.createSite(
          const DiveSite(
            id: 'nocode',
            name: 'Hertenstein',
            country: 'Switzerland',
            region: 'Lucerne',
            city: 'Weggis',
            bodyOfWater: 'Lake Lucerne',
            location: GeoPoint(47.0, 8.4),
          ),
        );
        // createSite derives a code from the text; this site predates that.
        await db.customStatement(
          "UPDATE dive_sites SET country_code = NULL WHERE id = 'nocode'",
        );

        final summary = await service(
          _MapLocationService({'47.0,8.4': weggis}),
          mode: SiteLocationLookupMode.refreshAll,
        ).run(onProgress: (_, _) {}, isCancelled: () => false);

        expect(summary.updated, 1);
        expect((await sites.getSiteById('nocode'))!.countryCode, 'CH');
      },
    );
  });
  group('remembering what a lookup could not fill (issue #4992)', () {
    // Weggis has no body of water on OpenStreetMap in this script, so the
    // empty site keeps that one field blank after its lookup.
    const noWater = PlaceLookup(
      country: 'Switzerland',
      region: 'Lucerne',
      locality: 'Weggis',
    );
    // The partial site already has country and region; the lookup finds
    // nothing more, so town and body of water stay blank.
    const sameAsStored = PlaceLookup(country: 'Switzerland', region: 'Lucerne');
    const answers = {'47.0,8.4': noWater, '47.1,8.5': sameAsStored};

    Future<BackfillSummary> fill(
      _FakeMemory memory, [
      Map<String, PlaceLookup> scripted = answers,
    ]) => service(
      _MapLocationService(scripted),
      memory: memory,
    ).run(onProgress: (_, _) {}, isCancelled: () => false);

    Future<BackfillCandidates> next(_FakeMemory memory) =>
        service(_MapLocationService({}), memory: memory).candidates();

    test('a site whose blanks the lookup could not fill is not offered '
        'again', () async {
      await seed();
      final memory = _FakeMemory();

      final first = await fill(memory);
      expect(first.updated, 1, reason: 'empty gained country, region, town');
      expect(first.unchanged, 1, reason: 'partial: nothing new found');

      final again = await next(memory);
      expect(again.sites, isEmpty);
      expect(again.alreadyLookedUp, 2);
      expect(memory.notes['empty']!.blank, {SiteLocationField.bodyOfWater});
      expect(memory.notes['partial']!.blank, {
        SiteLocationField.city,
        SiteLocationField.bodyOfWater,
      });
    });

    test('a site that moved is offered again', () async {
      await seed();
      final memory = _FakeMemory();
      await fill(memory);

      final moved = (await sites.getSiteById('partial'))!;
      await sites.updateSite(
        moved.copyWith(location: const GeoPoint(47.15, 8.55)),
      );

      final again = await next(memory);
      expect(again.sites.map((s) => s.id), ['partial']);
      expect(again.alreadyLookedUp, 1);
    });

    test('a field cleared since the lookup offers the site again', () async {
      await seed();
      final memory = _FakeMemory();
      await fill(memory);

      final partial = (await sites.getSiteById('partial'))!;
      await sites.updateSite(partial.copyWith(region: ''));

      final again = await next(memory);
      expect(again.sites.map((s) => s.id), ['partial']);
    });

    test('a site filled completely leaves no note', () async {
      await seed();
      final memory = _FakeMemory();
      await fill(memory, {'47.0,8.4': weggis, '47.1,8.5': sameAsStored});
      expect(memory.notes.containsKey('empty'), isFalse);
      expect(memory.notes.containsKey('partial'), isTrue);
    });

    test('a failed or unreachable lookup is not remembered', () async {
      await seed();
      final memory = _FakeMemory();
      await service(
        _MapLocationService(answers, throwOn: '47.0,8.4'),
        memory: memory,
      ).run(onProgress: (_, _) {}, isCancelled: () => false);
      expect(memory.notes.keys, ['partial']);

      final offline = _FakeMemory();
      await service(
        _MapLocationService(answers, offline: true),
        memory: offline,
      ).run(onProgress: (_, _) {}, isCancelled: () => false);
      expect(offline.notes, isEmpty);
    });

    test('a lookup that found nothing at all is remembered', () async {
      // OpenStreetMap answered "nothing here" (open sea outside the sea
      // table, say): asking again would get the same answer.
      await seed();
      final memory = _FakeMemory();
      final summary = await fill(memory, const {});
      expect(summary.unchanged, 2);
      expect(memory.notes.keys, unorderedEquals(['empty', 'partial']));
      expect((await next(memory)).sites, isEmpty);
    });

    test('an address that could not be fetched is not remembered and counts '
        'as failed', () async {
      // A TLS error or a broken body: OpenStreetMap was never really asked,
      // so neither the note nor the "nothing to add" summary may claim it.
      await seed();
      final memory = _FakeMemory();
      const broken = PlaceLookup(addressUnknown: true);
      final summary = await fill(memory, {
        '47.0,8.4': broken,
        '47.1,8.5': broken,
      });
      expect(summary.failed, 2);
      expect(summary.unchanged, 0);
      for (final note in memory.notes.values) {
        expect(
          note.blank,
          isNot(contains(SiteLocationField.country)),
          reason: 'an address that was never fetched is not noted',
        );
      }
      expect((await next(memory)).sites, hasLength(2));
    });

    test('a sea name alone does not let a failed address be noted', () async {
      // The bundled sea table answers offline, so a marine site can come
      // back with a body of water although its address request failed.
      await seed();
      final memory = _FakeMemory();
      final summary = await fill(memory, {
        '47.0,8.4': const PlaceLookup(
          bodyOfWater: 'Lake Lucerne',
          addressUnknown: true,
        ),
        '47.1,8.5': sameAsStored,
      });
      expect(summary.updated, 1, reason: 'the body of water was written');
      expect(
        memory.notes.containsKey('empty'),
        isFalse,
        reason: 'its empty country, region and town were never asked',
      );
      expect((await next(memory)).sites.map((s) => s.id), ['empty']);
    });

    test('a body of water whose own lookup failed is asked again', () async {
      await seed();
      final memory = _FakeMemory();
      await fill(memory, {
        '47.0,8.4': noWater.copyWith(bodyOfWaterUnknown: true),
        '47.1,8.5': sameAsStored,
      });
      expect(
        memory.notes.containsKey('empty'),
        isFalse,
        reason: 'the only blank left is the one that was never asked',
      );
      expect((await next(memory)).sites.map((s) => s.id), ['empty']);
    });

    test(
      'a site that moved while its lookup was in flight is not noted',
      () async {
        await seed();
        final memory = _FakeMemory();
        // A sync moves the empty site while OpenStreetMap is being asked
        // about its old coordinates.
        final location = _MovingLocationService(answers, () async {
          final empty = (await sites.getSiteById('empty'))!;
          await sites.updateSite(
            empty.copyWith(location: const GeoPoint(46.0, 7.0)),
          );
        });

        await service(
          location,
          memory: memory,
        ).run(onProgress: (_, _) {}, isCancelled: () => false);

        expect(memory.notes.containsKey('empty'), isFalse);
        expect(memory.notes.containsKey('partial'), isTrue);
      },
    );

    test('a cancelled run keeps what it learned', () async {
      await seed();
      final memory = _FakeMemory();
      var calls = 0;
      await service(
        _MapLocationService(answers),
        memory: memory,
      ).run(onProgress: (_, _) {}, isCancelled: () => calls++ >= 1);
      expect(memory.notes, hasLength(1));
    });

    test('a refresh still asks about every site', () async {
      await seed();
      final memory = _FakeMemory();
      await fill(memory);

      final refresh = await service(
        _MapLocationService({}),
        mode: SiteLocationLookupMode.refreshAll,
        memory: memory,
      ).candidates();
      expect(
        refresh.sites.map((s) => s.id),
        unorderedEquals(['empty', 'partial', 'full']),
      );
      expect(refresh.alreadyLookedUp, 0);
    });

    test('notes for sites no longer listed are dropped', () async {
      await seed();
      final memory = _FakeMemory()
        ..notes = {
          'gone': const SiteLookupNote(
            latitude: 1,
            longitude: 2,
            blank: {SiteLocationField.city},
          ),
        };

      await next(memory);
      expect(memory.notes.containsKey('gone'), isFalse);
    });

    group('SiteLookupNote', () {
      const site = DiveSite(
        id: 's',
        name: 'S',
        country: 'a',
        region: 'b',
        location: GeoPoint(1, 2),
      );

      test('covers a site only at the same place with no new blank', () {
        final note = SiteLookupNote.of(site, const PlaceLookup(country: 'a'))!;
        expect(note.covers(site), isTrue);
        expect(note.covers(site.copyWith(city: 'c')), isTrue);
        expect(note.covers(site.copyWith(region: ' ')), isFalse);
        expect(
          note.covers(site.copyWith(location: const GeoPoint(1, 2.1))),
          isFalse,
        );
      });

      test('leaves out a field the lookup answered but that was not '
          'written', () {
        // A library site this profile may not edit keeps its blank town,
        // though OpenStreetMap named one: that is not OpenStreetMap's gap.
        final note = SiteLookupNote.of(
          site,
          const PlaceLookup(country: 'a', locality: 'Weggis'),
        )!;
        expect(note.blank, {SiteLocationField.bodyOfWater});
        expect(note.covers(site), isFalse);
      });

      test('is null without coordinates or without an unanswered blank', () {
        const found = PlaceLookup(country: 'a');
        expect(
          SiteLookupNote.of(const DiveSite(id: 'x', name: 'x'), found),
          isNull,
        );
        expect(
          SiteLookupNote.of(
            site,
            const PlaceLookup(locality: 'c', bodyOfWater: 'd'),
          ),
          isNull,
        );
      });
    });
  });
}
