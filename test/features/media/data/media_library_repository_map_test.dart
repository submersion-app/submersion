import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;
  late MediaLibraryRepository repo;

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertSite(String id, String name, {double? lat, double? lng}) =>
      db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion(
              id: Value(id),
              name: Value(name),
              latitude: Value(lat),
              longitude: Value(lng),
              createdAt: Value(epoch),
              updatedAt: Value(epoch),
            ),
          );

  Future<void> insertDive(
    String id, {
    required String diverId,
    int? number,
    String? siteId,
    double? entryLat,
    double? entryLng,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          diveNumber: Value(number),
          siteId: Value(siteId),
          entryLatitude: Value(entryLat),
          entryLongitude: Value(entryLng),
          diveDateTime: Value(
            TripMediaScanner.toWallClockUtc(
              DateTime(2026, 6, 12),
            ).millisecondsSinceEpoch,
          ),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertMedia(
    String id,
    DateTime takenAt, {
    String? diveId,
    String? siteId,
    double? lat,
    double? lng,
    MediaType mediaType = MediaType.photo,
  }) => mediaRepo.createMedia(
    MediaItem(
      id: id,
      mediaType: mediaType,
      sourceType: MediaSourceType.localFile,
      filePath: p.join('media', id),
      localPath: p.join('media', id),
      originalFilename: '$id.jpg',
      diveId: diveId,
      siteId: siteId,
      latitude: lat,
      longitude: lng,
      takenAt: TripMediaScanner.toWallClockUtc(takenAt),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    mediaRepo = MediaRepository();
    repo = MediaLibraryRepository();

    await insertDiver('d1');
    await insertDiver('d2');
    await insertSite('site-1', 'Blue Hole', lat: 12.5, lng: 43.2);
    await insertSite('site-att', 'Reef', lat: -8.0, lng: 115.0);
    await insertSite('site-nocoord', 'Nowhere');

    await insertDive('dive-1', diverId: 'd1', number: 1, siteId: 'site-1');
    await insertDive(
      'dive-entry',
      diverId: 'd1',
      number: 2,
      entryLat: 10.0,
      entryLng: 20.0,
    );
    await insertDive(
      'dive-entry-site',
      diverId: 'd1',
      number: 3,
      siteId: 'site-1',
      entryLat: 12.6,
      entryLng: 43.3,
    );
    await insertDive('dive-nocoord', diverId: 'd1', siteId: 'site-nocoord');
    await insertDive('dive-other', diverId: 'd2', siteId: 'site-1');

    final t = DateTime(2026, 6, 12, 10);
    await insertMedia('own', t, diveId: 'dive-1', lat: 1.0, lng: 2.0);
    await insertMedia(
      'zero',
      t.add(const Duration(minutes: 1)),
      diveId: 'dive-1',
      lat: 0,
      lng: 0,
    );
    await insertMedia(
      'entry',
      t.add(const Duration(minutes: 2)),
      diveId: 'dive-entry',
    );
    await insertMedia(
      'entry-over-site',
      t.add(const Duration(minutes: 3)),
      diveId: 'dive-entry-site',
    );
    await insertMedia(
      'site',
      t.add(const Duration(minutes: 4)),
      diveId: 'dive-1',
    );
    await insertMedia(
      'attached',
      t.add(const Duration(minutes: 5)),
      siteId: 'site-att',
    );
    await insertMedia(
      'unlinked',
      t.add(const Duration(minutes: 6)),
      lat: 5.0,
      lng: 6.0,
    );
    await insertMedia(
      'unlocated',
      t.add(const Duration(minutes: 7)),
      diveId: 'dive-nocoord',
    );
    await insertMedia(
      'doc',
      t.add(const Duration(minutes: 8)),
      diveId: 'dive-1',
      mediaType: MediaType.document,
    );
    await insertMedia(
      'sig',
      t.add(const Duration(minutes: 9)),
      diveId: 'dive-1',
      mediaType: MediaType.instructorSignature,
    );
    await insertMedia(
      'other',
      t.add(const Duration(minutes: 10)),
      diveId: 'dive-other',
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Map<String, MediaMapPoint> byId(List<MediaMapPoint> points) => {
    for (final p in points) p.item.id: p,
  };

  test('resolves every placement kind with its label', () async {
    final points = byId(await repo.getMapPoints(diverId: 'd1'));

    expect(points['own']!.point, const LatLng(1, 2));
    expect(points['own']!.placement, MediaPlacement.ownGps);
    expect(points['own']!.placeLabel, 'Blue Hole');

    expect(points['zero']!.point, const LatLng(12.5, 43.2));
    expect(points['zero']!.placement, MediaPlacement.diveSite);

    expect(points['entry']!.point, const LatLng(10, 20));
    expect(points['entry']!.placement, MediaPlacement.diveEntry);
    expect(points['entry']!.placeLabel, isNull);

    expect(points['entry-over-site']!.point, const LatLng(12.6, 43.3));
    expect(points['entry-over-site']!.placement, MediaPlacement.diveEntry);
    expect(points['entry-over-site']!.placeLabel, 'Blue Hole');

    expect(points['site']!.placement, MediaPlacement.diveSite);
    expect(points['site']!.entry.diveNumber, 1);

    expect(points['attached']!.point, const LatLng(-8, 115));
    expect(points['attached']!.placement, MediaPlacement.attachedSite);
    expect(points['attached']!.placeLabel, 'Reef');
    expect(points['attached']!.entry.siteName, 'Reef');

    expect(points['unlinked']!.placement, MediaPlacement.ownGps);
    expect(points['unlinked']!.placeLabel, isNull);
  });

  test('drops unlocated rows, documents and signatures', () async {
    final ids = (await repo.getMapPoints(diverId: 'd1')).map((p) => p.item.id);
    expect(ids, isNot(contains('unlocated')));
    expect(ids, isNot(contains('doc')));
    expect(ids, isNot(contains('sig')));
  });

  test('dive-linked rows are scoped to the diver; unlinked and site-only '
      'rows are global', () async {
    final d1 = (await repo.getMapPoints(diverId: 'd1')).map((p) => p.item.id);
    expect(d1, isNot(contains('other')));
    expect(d1, containsAll(['attached', 'unlinked']));

    final all = (await repo.getMapPoints(diverId: null)).map((p) => p.item.id);
    expect(all, contains('other'));
  });

  test('orders by date taken ascending', () async {
    final ids = (await repo.getMapPoints(
      diverId: 'd1',
    )).map((p) => p.item.id).toList();
    expect(ids, [
      'own',
      'zero',
      'entry',
      'entry-over-site',
      'site',
      'attached',
      'unlinked',
    ]);
  });

  test('honours the library filter', () async {
    final videos = await repo.getMapPoints(
      diverId: 'd1',
      filter: const MediaLibraryFilter(mediaType: MediaType.video),
    );
    expect(videos, isEmpty);

    final atSite = await repo.getMapPoints(
      diverId: 'd1',
      filter: const MediaLibraryFilter(siteId: 'site-att'),
    );
    expect(atSite.map((p) => p.item.id), ['attached']);
  });

  test(
    'countInScope counts photo and video rows the grid would show',
    () async {
      // d1: own, zero, entry, entry-over-site, site, attached, unlinked,
      // unlocated = 8 (doc, sig and the other diver's row excluded).
      expect(await repo.countInScope(diverId: 'd1'), 8);
      // So the map's unlocated count for d1 is 8 - 7 = 1.
      final located = await repo.getMapPoints(diverId: 'd1');
      expect(await repo.countInScope(diverId: 'd1') - located.length, 1);
    },
  );

  test('watchMapChanges emits on a site coordinate edit', () async {
    var fired = false;
    final sub = repo.watchMapChanges().listen((_) => fired = true);
    addTearDown(sub.cancel);

    await (db.update(db.diveSites)..where((s) => s.id.equals('site-1'))).write(
      const DiveSitesCompanion(latitude: Value(13.0)),
    );
    for (var i = 0; i < 150 && !fired; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(fired, isTrue);
  });

  test('getMapPoints rethrows a query failure', () async {
    await db.close();

    expect(repo.getMapPoints(diverId: 'd1'), throwsA(anything));
  });

  test('an item placed at its attached site is labelled with that site, '
      "not its dive's site", () async {
    // The dive's site has no coordinates, so placement falls through to the
    // row's own attached site; the label must name where it actually sits.
    await insertMedia(
      'both-sites',
      DateTime(2026, 6, 12, 11),
      diveId: 'dive-nocoord',
      siteId: 'site-att',
    );

    final points = byId(await repo.getMapPoints(diverId: 'd1'));
    final point = points['both-sites']!;
    expect(point.placement, MediaPlacement.attachedSite);
    expect(point.placeLabel, 'Reef');
    expect(point.entry.siteName, 'Reef');
  });
}
