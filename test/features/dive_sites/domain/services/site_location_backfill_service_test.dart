import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';

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

void main() {
  late SiteRepository sites;

  setUp(() async {
    await setUpTestDatabase();
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

  SiteLocationBackfillService service(LocationService location) =>
      SiteLocationBackfillService(
        sites: sites,
        location: location,
        languageCode: 'en',
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
    expect(found.map((s) => s.id), unorderedEquals(['empty', 'partial']));
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
}
