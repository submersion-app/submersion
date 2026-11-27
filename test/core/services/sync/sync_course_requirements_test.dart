import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Serializer-level coverage for the course requirement tracker entities:
/// `courseRequirements` (HLC merge-root) and `courseRequirementDives`
/// (clockless junction whose delta export rides the parent requirement's
/// hlc, and whose deterministic id converges concurrent links).
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedFixture({String? requirementHlc}) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO courses (id, diver_id, name, agency, start_date, "
      "created_at, updated_at) "
      "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
      "updated_at) VALUES ('dive-1', 'diver-1', 2000, 1000, 1000)",
    );
    final hlcCol = requirementHlc != null ? "'$requirementHlc'" : 'NULL';
    await db.customStatement(
      "INSERT INTO course_requirements (id, course_id, name, kind, "
      "target_count, sort_order, created_at, updated_at, hlc) "
      "VALUES ('req-1', 'course-1', 'Deep adventure dive', 'dive', 1, 0, "
      "1000, 1000, $hlcCol)",
    );
    await db.customStatement(
      "INSERT INTO course_requirement_dives (id, requirement_id, dive_id, "
      "created_at) VALUES ('link-1', 'req-1', 'dive-1', 1000)",
    );
  }

  test('full export/import round-trip preserves both tables', () async {
    await seedFixture();
    final db = DatabaseService.instance.database;

    final payload = await serializer.exportChangeset(
      deviceId: 'dev-1',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(payload.data.courseRequirements, hasLength(1));
    expect(payload.data.courseRequirementDives, hasLength(1));
    final requirementJson = payload.data.courseRequirements.single;
    final linkJson = payload.data.courseRequirementDives.single;

    await db.customStatement('DELETE FROM course_requirement_dives');
    await db.customStatement('DELETE FROM course_requirements');

    await serializer.upsertRecord('courseRequirements', requirementJson);
    await serializer.upsertRecord('courseRequirementDives', linkJson);

    final requirement = await db
        .customSelect(
          "SELECT id, course_id, name, kind, target_count "
          "FROM course_requirements",
        )
        .getSingle();
    expect(requirement.data['id'], 'req-1');
    expect(requirement.data['course_id'], 'course-1');
    expect(requirement.data['name'], 'Deep adventure dive');
    expect(requirement.data['kind'], 'dive');
    expect(requirement.data['target_count'], 1);

    final link = await db
        .customSelect(
          'SELECT id, requirement_id, dive_id FROM course_requirement_dives',
        )
        .getSingle();
    expect(link.data['id'], 'link-1');
    expect(link.data['requirement_id'], 'req-1');
    expect(link.data['dive_id'], 'dive-1');
  });

  test('both derived requirement kinds survive export and import', () async {
    await seedFixture();
    final db = DatabaseService.instance.database;
    const queryJson = '{"version":1,"node":{"t":"text","words":["training"]}}';
    await db.customStatement(
      "INSERT INTO course_requirements (id, course_id, name, kind, "
      "target_count, created_at, updated_at, equipment_id, query_json) "
      "VALUES ('ccr', 'course-1', 'CCR time', 'ccrHours', 40, 1000, 1000, ?, NULL), "
      "('search', 'course-1', 'Training dives', 'diveQuery', 20, 1000, 1000, NULL, ?)",
      ['rebreather-1', queryJson],
    );
    final payload = await serializer.exportChangeset(
      deviceId: 'dev-1',
      hlcWatermark: null,
      deletions: const [],
    );
    await db.customStatement(
      "DELETE FROM course_requirements WHERE id != 'req-1'",
    );
    for (final row in payload.data.courseRequirements) {
      await serializer.upsertRecord('courseRequirements', row);
    }

    final ccr = await serializer.fetchRecord('courseRequirements', 'ccr');
    final search = await serializer.fetchRecord('courseRequirements', 'search');
    expect(ccr, containsPair('kind', 'ccrHours'));
    expect(ccr, containsPair('equipmentId', 'rebreather-1'));
    expect(search, containsPair('kind', 'diveQuery'));
    expect(search, containsPair('queryJson', queryJson));
  });

  test('junction delta export rides the parent requirement hlc', () async {
    await seedFixture(requirementHlc: '2026-01-02T00:00:00.000Z-0000-peer-dev');

    final included = await serializer.exportChangeset(
      deviceId: 'dev-1',
      hlcWatermark: '2026-01-01T00:00:00.000Z-0000-peer-dev',
      deletions: const [],
    );
    expect(included.data.courseRequirements, hasLength(1));
    expect(included.data.courseRequirementDives, hasLength(1));

    final excluded = await serializer.exportChangeset(
      deviceId: 'dev-1',
      hlcWatermark: '2026-12-31T00:00:00.000Z-0000-peer-dev',
      deletions: const [],
    );
    expect(excluded.data.courseRequirements, isEmpty);
    expect(excluded.data.courseRequirementDives, isEmpty);
  });

  test('re-upserting the same junction row converges to one row', () async {
    await seedFixture();
    final db = DatabaseService.instance.database;

    const linkJson = {
      'id': 'link-1',
      'requirementId': 'req-1',
      'diveId': 'dive-1',
      'createdAt': 1000,
    };
    await serializer.upsertRecord('courseRequirementDives', linkJson);
    await serializer.upsertRecord('courseRequirementDives', linkJson);

    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM course_requirement_dives')
        .getSingle();
    expect(count.data['c'], 1);
  });
}
