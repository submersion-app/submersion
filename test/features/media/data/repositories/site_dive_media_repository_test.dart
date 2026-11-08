import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/site_dive_media_repository.dart';

import '../../../../helpers/drift_statement_log.dart';
import '../../../../helpers/test_database.dart';

/// The site's "Photos from dives" group reads its count and its media
/// straight from the media table, without hydrating the site's dives or
/// querying once per dive (issue #4252).
void main() {
  late AppDatabase db;
  late SiteDiveMediaRepository repository;

  Future<void> site(String id) => db.customStatement(
    'INSERT INTO dive_sites (id, name, created_at, updated_at) '
    'VALUES (?, ?, 0, 0)',
    [id, id],
  );

  Future<void> dive(String id, String? siteId) => db.customStatement(
    'INSERT INTO dives (id, dive_date_time, site_id, created_at, updated_at) '
    'VALUES (?, 0, ?, 0, 0)',
    [id, siteId],
  );

  Future<void> media(
    String id, {
    String? diveId,
    String? siteId,
    int? takenAt = 1000,
    String fileType = 'photo',
  }) => db.customStatement(
    'INSERT INTO media (id, dive_id, site_id, file_path, file_type, taken_at, '
    'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0, 0)',
    [id, diveId, siteId, '/photos/$id.jpg', fileType, takenAt],
  );

  Future<void> enrichment(String mediaId, String diveId, double depth) =>
      db.customStatement(
        'INSERT INTO media_enrichment (id, media_id, dive_id, depth_meters, '
        'created_at) VALUES (?, ?, ?, ?, 0)',
        ['e-$mediaId', mediaId, diveId, depth],
      );

  Future<void> openDatabase({bool logStatements = false}) async {
    db = logStatements
        ? await setUpStatementLoggingTestDatabase()
        : await setUpTestDatabase();
    repository = SiteDiveMediaRepository();
    await site('S');
    await site('other');
  }

  setUp(openDatabase);
  tearDown(tearDownTestDatabase);

  group('countMediaFromDivesAtSite', () {
    test('is zero for a site whose dives have no media', () async {
      await dive('d1', 'S');
      await dive('d2', 'S');
      expect(await repository.countMediaFromDivesAtSite('S'), 0);
    });

    test('counts media on every dive at the site and nothing else', () async {
      await dive('d1', 'S');
      await dive('d2', 'S');
      await dive('elsewhere', 'other');
      await dive('no-site', null);
      await media('a', diveId: 'd1');
      await media('b', diveId: 'd1');
      await media('c', diveId: 'd2', fileType: 'video');
      await media('x', diveId: 'elsewhere');
      await media('y', diveId: 'no-site');
      // Attached to the site directly, not through a dive: the attachments
      // group shows it, the dive group does not.
      await media('direct', siteId: 'S');

      expect(await repository.countMediaFromDivesAtSite('S'), 3);
    });

    test('a dive photo also attached to the site counts once', () async {
      await dive('d1', 'S');
      await media('both', diveId: 'd1', siteId: 'S');
      expect(await repository.countMediaFromDivesAtSite('S'), 1);
    });
  });

  group('getMediaFromDivesAtSite', () {
    test('is empty when no dive at the site has media', () async {
      await dive('d1', 'S');
      expect(await repository.getMediaFromDivesAtSite('S'), isEmpty);
    });

    test('returns every dive media item in chronological order', () async {
      await dive('d1', 'S');
      await dive('d2', 'S');
      await dive('elsewhere', 'other');
      await media('late', diveId: 'd1', takenAt: 3000);
      await media('early', diveId: 'd2', takenAt: 1000);
      await media('middle', diveId: 'd1', takenAt: 2000);
      // Same instant: id breaks the tie so the order is stable.
      await media('middle-b', diveId: 'd2', takenAt: 2000);
      await media('x', diveId: 'elsewhere', takenAt: 1500);
      await media('direct', siteId: 'S', takenAt: 1200);

      final items = await repository.getMediaFromDivesAtSite('S');
      expect(items.map((m) => m.id), ['early', 'middle', 'middle-b', 'late']);
      expect(items.map((m) => m.diveId), ['d2', 'd1', 'd2', 'd1']);
    });

    test('carries the enrichment of items that have one', () async {
      await dive('d1', 'S');
      await media('a', diveId: 'd1', takenAt: 1000);
      await media('b', diveId: 'd1', takenAt: 2000);
      await enrichment('a', 'd1', 18.5);

      final items = await repository.getMediaFromDivesAtSite('S');
      expect(items.first.enrichment?.depthMeters, 18.5);
      expect(items.last.enrichment, isNull);
    });
  });

  // The provider this replaced hydrated every dive at the site, profile and
  // tank-pressure series included, then queried once per dive.
  group('statement budget', () {
    setUp(() async {
      await tearDownTestDatabase();
      await withoutStatementLog(() async {
        await openDatabase(logStatements: true);
        for (var i = 0; i < 40; i++) {
          await dive('d$i', 'S');
          if (i.isEven) await media('m$i', diveId: 'd$i', takenAt: i);
        }
      });
    });

    test('the count is one statement however many dives', () async {
      late int count;
      final sent = await statementsOf(() async {
        count = await repository.countMediaFromDivesAtSite('S');
      });
      expect(count, 20);
      expect(sent, hasLength(1));
      expect(sent.where(readsSeriesBlob), isEmpty);
    });

    test('the media is one statement however many dives', () async {
      late int length;
      final sent = await statementsOf(() async {
        length = (await repository.getMediaFromDivesAtSite('S')).length;
      });
      expect(length, 20);
      expect(sent, hasLength(1));
      expect(sent.where(readsSeriesBlob), isEmpty);
    });
  });
}
