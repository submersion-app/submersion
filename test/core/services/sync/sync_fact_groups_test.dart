import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('registry', () {
    test('media declares an upload and a verification group', () {
      expect(SyncFactGroups.of('media').map((g) => g.name), [
        'upload',
        'verification',
      ]);
      expect(SyncFactGroups.of('dives'), isEmpty);
    });

    test('every declared column and clock exists on the table', () async {
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      final media = db.allTables.firstWhere(
        (t) => t.actualTableName == 'media',
      );
      final sqlNames = media.$columns.map((c) => c.name).toSet();
      for (final g in SyncFactGroups.of('media')) {
        expect(sqlNames, contains(g.clockColumn), reason: g.name);
        expect(sqlNames, containsAll(g.columns.values), reason: g.name);
      }
    });

    test('the JSON keys match the synced row', () async {
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await db.customStatement(
        "INSERT INTO media (id, file_path, created_at, updated_at) "
        "VALUES ('m1', '/x.jpg', 0, 0)",
      );
      final row = (await db.select(db.media).getSingle()).toJson();
      for (final g in SyncFactGroups.of('media')) {
        expect(row.keys, contains(g.clockKey), reason: g.name);
        expect(row.keys, containsAll(g.columns.keys), reason: g.name);
      }
    });

    test('every entity with groups names the table its clock lives on', () {
      for (final entity in SyncFactGroups.byEntity.keys) {
        final target = SyncRepository.hlcTargets[entity];
        final own = SyncFactGroups.tables[entity];
        expect(own, isNotNull, reason: entity);
        expect(own!.table, target!.table, reason: entity);
        expect(own.pk, target.pk, reason: entity);
      }
    });

    test('no column belongs to two groups', () {
      final all = [
        for (final g in SyncFactGroups.of('media')) ...g.columns.keys,
      ];
      expect(all.toSet().length, all.length);
    });
  });

  group('mergeFactGroups', () {
    Map<String, dynamic> row({
      String hlc = 'H0',
      String? upload,
      String? verify,
      int? uploadedAt,
      String? hash,
      bool orphaned = false,
    }) => {
      'id': 'm1',
      'caption': 'c-$hlc',
      'hlc': hlc,
      'uploadFactsHlc': upload,
      'verifyFactsHlc': verify,
      'contentHash': hash,
      'contentSizeBytes': hash == null ? null : 10,
      'remoteUploadedAt': uploadedAt,
      'remoteThumbUploadedAt': null,
      'remoteCompressedUploadedAt': null,
      'compressedLevel': null,
      'compressedSizeBytes': null,
      'isOrphaned': orphaned,
      'lastVerifiedAt': null,
    };

    test('the peer wins a group only with a strictly newer clock', () {
      final local = row(hlc: 'H5', upload: 'H3');
      final remote = row(hlc: 'H1', upload: 'H4', uploadedAt: 99, hash: 'h');
      final r = mergeFactGroups(
        entityType: 'media',
        base: local,
        local: local,
        remote: remote,
      );
      expect(r.row['caption'], 'c-H5', reason: 'the row stays local');
      expect(r.row['remoteUploadedAt'], 99);
      expect(r.row['contentHash'], 'h');
      expect(r.row['uploadFactsHlc'], 'H4');
      expect(r.fromRemote.map((g) => g.name), ['upload']);
    });

    test('a newer clear lands as null', () {
      final local = row(upload: 'H2', uploadedAt: 50, hash: 'h');
      final remote = row(upload: 'H3', hash: 'h');
      final r = mergeFactGroups(
        entityType: 'media',
        base: local,
        local: local,
        remote: remote,
      );
      expect(r.row.containsKey('remoteUploadedAt'), isTrue);
      expect(r.row['remoteUploadedAt'], isNull);
    });

    test('an older or tied peer clock keeps local', () {
      final local = row(upload: 'H3', uploadedAt: 50);
      for (final clock in ['H2', 'H3']) {
        final r = mergeFactGroups(
          entityType: 'media',
          base: local,
          local: local,
          remote: row(upload: clock, uploadedAt: 1),
        );
        expect(r.row['remoteUploadedAt'], 50, reason: clock);
        expect(r.fromRemote, isEmpty);
      }
    });

    test('a legacy peer without fact clocks orders by its row clock', () {
      final local = row(hlc: 'H2', upload: 'H2');
      final remote = row(hlc: 'H6', uploadedAt: 7)
        ..remove('uploadFactsHlc')
        ..remove('verifyFactsHlc');
      final r = mergeFactGroups(
        entityType: 'media',
        base: remote,
        local: local,
        remote: remote,
      );
      expect(r.row['remoteUploadedAt'], 7);
      expect(r.row['uploadFactsHlc'], 'H6');
    });

    test('groups resolve independently', () {
      final local = row(upload: 'H5', verify: 'H1', uploadedAt: 5);
      final remote = row(
        upload: 'H1',
        verify: 'H5',
        uploadedAt: 1,
        orphaned: true,
      );
      final r = mergeFactGroups(
        entityType: 'media',
        base: local,
        local: local,
        remote: remote,
      );
      expect(r.row['remoteUploadedAt'], 5);
      expect(r.row['isOrphaned'], isTrue);
    });

    test('a column the peer omits keeps the local value', () {
      // An older build sends no key for a column it does not know. That is
      // not a clear, and writing null for it would erase a fact this device
      // holds; an explicit null still clears (the test above).
      final local = row(hlc: 'H1', upload: 'H1', uploadedAt: 50, hash: 'h');
      final remote = row(hlc: 'H9', upload: 'H9')
        ..remove('remoteUploadedAt')
        ..remove('contentHash');
      final r = mergeFactGroups(
        entityType: 'media',
        base: remote,
        local: local,
        remote: remote,
      );
      expect(r.row['remoteUploadedAt'], 50);
      expect(r.row['contentHash'], 'h');
      expect(r.row['uploadFactsHlc'], 'H9');
    });

    test('a column neither side carries stays absent, never null', () {
      final local = row(upload: 'H1')..remove('remoteUploadedAt');
      final remote = row(upload: 'H2')..remove('remoteUploadedAt');
      final r = mergeFactGroups(
        entityType: 'media',
        base: remote,
        local: local,
        remote: remote,
      );
      expect(
        r.row.containsKey('remoteUploadedAt'),
        isFalse,
        reason: 'the writer must not clear what nobody sent',
      );
    });

    test('an entity without groups returns base untouched', () {
      final base = {'id': 'd1', 'hlc': 'H1'};
      final r = mergeFactGroups(
        entityType: 'dives',
        base: base,
        local: base,
        remote: base,
      );
      expect(r.row, base);
      expect(r.fromRemote, isEmpty);
    });

    test('no local row takes every group from the peer', () {
      final remote = row(upload: 'H1', uploadedAt: 3);
      final r = mergeFactGroups(
        entityType: 'media',
        base: remote,
        local: null,
        remote: remote,
      );
      expect(r.row['remoteUploadedAt'], 3);
    });

    test('both clocks missing follows the base row', () {
      final local = row(uploadedAt: 1)
        ..remove('hlc')
        ..remove('uploadFactsHlc');
      final remote = row(uploadedAt: 2)
        ..remove('hlc')
        ..remove('uploadFactsHlc');
      final r = mergeFactGroups(
        entityType: 'media',
        base: remote,
        local: local,
        remote: remote,
      );
      expect(r.row['remoteUploadedAt'], 2);
    });
  });
}
