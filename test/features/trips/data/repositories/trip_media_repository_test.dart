import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_media_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_media_preview.dart';

import '../../../../helpers/test_database.dart';

/// Trip previews read the whole trip in one bounded statement rather than one
/// query per dive (issue #3832), and the gallery reads it in one statement
/// when it opens.
void main() {
  late AppDatabase db;
  late TripMediaRepository repository;

  Future<void> trip(String id, {String? parent}) => db.customStatement(
    'INSERT INTO trips (id, name, start_date, end_date, parent_trip_id, '
    'created_at, updated_at) VALUES (?, ?, 0, 0, ?, 0, 0)',
    [id, id, parent],
  );

  Future<void> diver(String id) => db.customStatement(
    'INSERT INTO divers (id, name, created_at, updated_at) '
    'VALUES (?, ?, 0, 0)',
    [id, id],
  );

  Future<void> dive(
    String id,
    String tripId, {
    String? diverId,
    bool excludedFromStats = false,
  }) => db.customStatement(
    'INSERT INTO dives (id, diver_id, dive_date_time, trip_id, '
    'excluded_from_stats, created_at, updated_at) '
    'VALUES (?, ?, 0, ?, ?, 0, 0)',
    [id, diverId, tripId, if (excludedFromStats) 1 else 0],
  );

  Future<void> media(
    String id,
    String? diveId, {
    int? takenAt = 1000,
    String fileType = 'photo',
  }) => db.customStatement(
    'INSERT INTO media (id, dive_id, file_path, file_type, taken_at, '
    'created_at, updated_at) VALUES (?, ?, ?, ?, ?, 0, 0)',
    [id, diveId, '/photos/$id.jpg', fileType, takenAt],
  );

  Future<void> enrichment(String mediaId, String diveId, double depth) =>
      db.customStatement(
        'INSERT INTO media_enrichment (id, media_id, dive_id, depth_meters, '
        'created_at) VALUES (?, ?, ?, ?, 0)',
        ['e-$mediaId', mediaId, diveId, depth],
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repository = TripMediaRepository();
    await trip('T');
  });
  tearDown(tearDownTestDatabase);

  group('getPreview', () {
    test('a trip with no media has an empty preview', () async {
      await dive('d1', 'T');
      final preview = await repository.getPreview('T');
      expect(preview.byDiveId, isEmpty);
      expect(preview.mediaCount, 0);
    });

    test('caps a dive at the preview limit, earliest first', () async {
      await dive('d1', 'T');
      for (var i = 0; i < tripMediaPreviewLimit + 4; i++) {
        // Inserted newest first, so insertion order cannot pass for chronology.
        await media('m$i', 'd1', takenAt: 1000 - i);
      }

      final preview = await repository.getPreview('T');
      final dive1 = preview.byDiveId['d1']!;

      expect(dive1.items, hasLength(tripMediaPreviewLimit));
      expect(dive1.mediaCount, tripMediaPreviewLimit + 4);
      expect(dive1.items.map((m) => m.id).toList(), [
        for (var i = tripMediaPreviewLimit + 3; i >= 4; i--) 'm$i',
      ]);
    });

    test('breaks a taken_at tie by id', () async {
      await dive('d1', 'T');
      await media('b', 'd1');
      await media('c', 'd1');
      await media('a', 'd1');

      final preview = await repository.getPreview('T');

      expect(preview.byDiveId['d1']!.items.map((m) => m.id), ['a', 'b', 'c']);
    });

    test('a row with no taken_at sorts after dated rows', () async {
      await dive('d1', 'T');
      await media('undated', 'd1', takenAt: null);
      await media('dated', 'd1');

      final preview = await repository.getPreview('T');

      expect(preview.byDiveId['d1']!.items.map((m) => m.id), [
        'dated',
        'undated',
      ]);
    });

    test('counts photos separately from other media', () async {
      await dive('d1', 'T');
      await media('photo', 'd1');
      await media('video', 'd1', fileType: 'video');
      await media('document', 'd1', fileType: 'document');
      await media('sig', 'd1', fileType: 'instructor_signature');
      await media('legacy-sig', 'd1', fileType: 'instructorSignature');
      await media('buddy-sig', 'd1', fileType: 'buddy_signature');

      final preview = await repository.getPreview('T');
      final dive1 = preview.byDiveId['d1']!;

      expect(dive1.mediaCount, 6);
      expect(dive1.photoCount, 1);
    });

    test('photo counts cover rows past the preview limit', () async {
      await dive('d1', 'T');
      for (var i = 0; i < tripMediaPreviewLimit; i++) {
        await media('v$i', 'd1', takenAt: i, fileType: 'video');
      }
      await media('late-photo', 'd1', takenAt: 9999);

      final preview = await repository.getPreview('T');

      expect(preview.byDiveId['d1']!.photoCount, 1);
    });

    test('includes side trip dives on the parent trip', () async {
      await trip('S', parent: 'T');
      await dive('p1', 'T');
      await dive('s1', 'S');
      await media('on-parent', 'p1');
      await media('on-side', 's1');

      final parent = await repository.getPreview('T');
      final side = await repository.getPreview('S');

      expect(parent.byDiveId.keys, unorderedEquals(['p1', 's1']));
      expect(side.byDiveId.keys, ['s1']);
    });

    test('leaves out other trips and media on no dive', () async {
      await trip('other');
      await dive('d1', 'T');
      await dive('o1', 'other');
      await media('mine', 'd1');
      await media('theirs', 'o1');
      await media('loose', null);

      final preview = await repository.getPreview('T');

      expect(preview.byDiveId.keys, ['d1']);
      expect(preview.mediaCount, 1);
    });

    test('a diver sees only their own dives on a shared trip', () async {
      await diver('me');
      await diver('buddy');
      await dive('mine', 'T', diverId: 'me');
      await dive('theirs', 'T', diverId: 'buddy');
      await media('m1', 'mine');
      await media('v1', 'mine', fileType: 'video');
      await media('m2', 'theirs');

      final scoped = await repository.getPreview('T', diverId: 'me');
      final everyone = await repository.getPreview('T');

      expect(scoped.byDiveId.keys, ['mine']);
      expect(scoped.byDiveId['mine']!.mediaCount, 2);
      expect(scoped.byDiveId['mine']!.photoCount, 1);
      expect(everyone.byDiveId.keys, unorderedEquals(['mine', 'theirs']));
    });

    test('keeps a dive excluded from statistics, like the dive list', () async {
      await dive('d1', 'T', excludedFromStats: true);
      await media('m1', 'd1');

      final preview = await repository.getPreview('T');

      expect(preview.byDiveId.keys, ['d1']);
    });
  });

  group('getMediaForTrip', () {
    test('returns every item in chronological order', () async {
      await dive('d1', 'T');
      await dive('d2', 'T');
      await media('late', 'd1', takenAt: 3000);
      await media('early', 'd2', takenAt: 1000);
      await media('middle', 'd1', takenAt: 2000);

      final items = await repository.getMediaForTrip('T');

      expect(items.map((m) => m.id), ['early', 'middle', 'late']);
    });

    test('carries enrichment for the viewer', () async {
      await dive('d1', 'T');
      await media('with', 'd1');
      await media('without', 'd1', takenAt: 2000);
      await enrichment('with', 'd1', 18.5);

      final items = await repository.getMediaForTrip('T');

      expect(items.first.enrichment?.depthMeters, 18.5);
      expect(items.first.enrichment?.mediaId, 'with');
      expect(items.last.enrichment, isNull);
    });

    test('hydrates the media row fields', () async {
      await dive('d1', 'T');
      await media('v1', 'd1', fileType: 'video');

      final item = (await repository.getMediaForTrip('T')).single;

      expect(item.id, 'v1');
      expect(item.diveId, 'd1');
      expect(item.mediaType, MediaType.video);
      expect(item.filePath, '/photos/v1.jpg');
      expect(item.takenAt.isUtc, isTrue);
    });

    test('follows the same side trip and diver scope as previews', () async {
      await diver('me');
      await diver('buddy');
      await trip('S', parent: 'T');
      await dive('mine', 'T', diverId: 'me');
      await dive('side', 'S', diverId: 'me');
      await dive('theirs', 'T', diverId: 'buddy');
      await media('m1', 'mine');
      await media('m2', 'side');
      await media('m3', 'theirs');

      final items = await repository.getMediaForTrip('T', diverId: 'me');

      expect(items.map((m) => m.id), unorderedEquals(['m1', 'm2']));
    });
  });

  group('statements and returned rows', () {
    // A statement-logging database, prints captured in a zone (the recipe of
    // equipment_list_tags_statement_count_test.dart).
    Future<int> countStatements(Future<void> Function() body) async {
      final logged = <String>[];
      await runZoned(
        body,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logged.add(line),
        ),
      );
      // Count statements, not print calls: a long argument list reaches the
      // zone's print hook in more than one piece.
      return logged.where((line) => line.startsWith('Drift: Sent')).length;
    }

    /// [dives] dives, a third of them empty, the rest with 40 rows each.
    Future<int> seedTrip(AppDatabase logging, int dives) async {
      var rows = 0;
      await runZoned(() async {
        await logging.customStatement(
          'INSERT INTO trips (id, name, start_date, end_date, created_at, '
          "updated_at) VALUES ('big', 'big', 0, 0, 0, 0)",
        );
        for (var d = 0; d < dives; d++) {
          await logging.customStatement(
            'INSERT INTO dives (id, dive_date_time, trip_id, created_at, '
            "updated_at) VALUES (?, ?, 'big', 0, 0)",
            ['d$d', d],
          );
          if (d % 3 == 0) continue;
          for (var m = 0; m < 40; m++) {
            await logging.customStatement(
              'INSERT INTO media (id, dive_id, file_path, file_type, '
              "taken_at, created_at, updated_at) VALUES (?, ?, 'p', "
              "'photo', ?, 0, 0)",
              ['m${rows++}', 'd$d', m],
            );
          }
        }
      }, zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}));
      return rows;
    }

    for (final dives in const [20, 100, 300]) {
      test('$dives dives: one statement each, previews capped', () async {
        await db.close();
        final logging = AppDatabase(
          NativeDatabase.memory(
            setup: registerAppSqlFunctions,
            logStatements: true,
          ),
        );
        DatabaseService.instance.setTestDatabase(logging);
        final rows = await seedTrip(logging, dives);

        late TripMediaPreview preview;
        final previewStatements = await countStatements(() async {
          preview = await repository.getPreview('big');
        });
        late List<MediaItem> full;
        final fullStatements = await countStatements(() async {
          full = await repository.getMediaForTrip('big');
        });

        expect(previewStatements, 1);
        expect(fullStatements, 1);

        final diveCount = dives - (dives + 2) ~/ 3;
        expect(preview.byDiveId, hasLength(diveCount));
        expect(preview.mediaCount, rows);
        expect(
          preview.byDiveId.values.fold<int>(0, (n, d) => n + d.items.length),
          diveCount * tripMediaPreviewLimit,
        );
        expect(full, hasLength(rows));
      });
    }
  });
}
