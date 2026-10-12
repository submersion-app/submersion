import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_course_identity.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Sync replication for the `dive_courses` junction (issue #2515). Its ids are
/// deterministic, so the same link made on two devices is one row, and an
/// older app version that writes only `dives.course_id` still reaches the set.
void main() {
  group('dive_courses sync (#2515)', () {
    late FakeCloudStorageProvider cloud;
    late AppDatabase db;

    setUp(() async {
      db = await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
      await db
          .into(db.divers)
          .insert(
            const DiversCompanion(
              id: Value('diver-1'),
              name: Value('D'),
              createdAt: Value(0),
              updatedAt: Value(0),
            ),
          );
      for (final (id, day) in [('c1', 1), ('c2', 2), ('c3', 3)]) {
        await db
            .into(db.courses)
            .insert(
              CoursesCompanion(
                id: Value(id),
                diverId: const Value('diver-1'),
                name: Value('Course $id'),
                agency: const Value('tdi'),
                startDate: Value(day),
                createdAt: const Value(0),
                updatedAt: const Value(0),
              ),
            );
      }
      await db
          .into(db.dives)
          .insert(
            const DivesCompanion(
              id: Value('v1'),
              diverId: Value('diver-1'),
              diveDateTime: Value(1000),
              courseId: Value('c1'),
              createdAt: Value(1000),
              updatedAt: Value(1000),
            ),
          );
    });

    tearDown(tearDownTestDatabase);

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    Map<String, dynamic> link(String diveId, String courseId) => {
      'id': diveCourseLinkId(diveId, courseId),
      'diveId': diveId,
      'courseId': courseId,
      'createdAt': 1000,
    };

    SyncPayload payloadOf(SyncData data, Map<String, List<SyncDeletion>> dels) {
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString();
      return SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-dev',
        checksum: checksum,
        data: data,
        deletions: dels,
      );
    }

    Future<Set<String>> coursesOf(String diveId) async => {
      for (final r in await (db.select(
        db.diveCourses,
      )..where((t) => t.diveId.equals(diveId))).get())
        r.courseId,
    };

    Future<void> sync(SyncPayload payload) async {
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);
      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));
    }

    test('a peer link replicates', () async {
      await sync(payloadOf(SyncData(diveCourses: [link('v1', 'c2')]), {}));
      expect(await coursesOf('v1'), containsAll(['c2']));
    });

    test('the same link made on both devices converges to one row', () async {
      await SyncDataSerializer().upsertRecord('diveCourses', link('v1', 'c2'));
      await sync(payloadOf(SyncData(diveCourses: [link('v1', 'c2')]), {}));
      final rows = await (db.select(
        db.diveCourses,
      )..where((t) => t.courseId.equals('c2'))).get();
      expect(rows, hasLength(1));
    });

    test(
      'a representative-only dive gains the course and keeps others',
      () async {
        final serializer = SyncDataSerializer();
        await serializer.upsertRecord('diveCourses', link('v1', 'c1'));
        await serializer.upsertRecord('diveCourses', link('v1', 'c2'));
        // An older app version: it rewrote dives.course_id and sent no links.
        final row = await (db.select(
          db.dives,
        )..where((t) => t.id.equals('v1'))).getSingle();
        final remote = row.toJson()
          ..['courseId'] = 'c3'
          ..['updatedAt'] = 5000;
        await sync(payloadOf(SyncData(dives: [remote]), {}));
        expect(await coursesOf('v1'), {'c1', 'c2', 'c3'});
      },
    );

    test('a peer tombstone removes the link', () async {
      await SyncDataSerializer().upsertRecord('diveCourses', link('v1', 'c2'));
      await sync(
        payloadOf(const SyncData(), {
          'diveCourses': [
            SyncDeletion(id: diveCourseLinkId('v1', 'c2'), deletedAt: 5000),
          ],
        }),
      );
      expect(await coursesOf('v1'), isNot(contains('c2')));
    });
  });
}
