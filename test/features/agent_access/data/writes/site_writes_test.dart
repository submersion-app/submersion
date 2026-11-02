import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/site_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

class _ReadOnlyStamper extends LibraryEditStamper {
  @override
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async => false;
}

void main() {
  late AppDatabase db;
  late RecordHarness h;
  late SiteWrites writes;

  Future<void> site(String id, String? owner, {String? library}) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: id,
          createdAt: kSeedTime,
          updatedAt: kSeedTime,
          diverId: Value(owner),
          country: const Value('Belize'),
          hazards: const Value('Strong current'),
          latitude: const Value(17.3),
          longitude: const Value(-87.5),
          sharedLibraryId: Value(library),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    writes = SiteWrites(RecordRepositories());
    await site('s1', kDiverA);
  });

  tearDown(() => tearDownTestDatabase());

  test('update writes only the named columns', () async {
    await writes.update(
      's1',
      kDiverA,
      const RecordUpdate(values: {'name': 'Blue Hole'}),
    );

    final doc = (await h.one('sites', 's1'))!;
    expect(doc['name'], 'Blue Hole');
    expect(doc['country'], 'Belize');
    expect(doc['latitude'], 17.3);
  });

  test('null clears a nullable column', () async {
    await writes.update(
      's1',
      kDiverA,
      const RecordUpdate(values: {'hazards': null, 'country': null}),
    );

    final doc = (await h.one('sites', 's1'))!;
    expect(doc['hazards'], isNull);
    expect(doc['country'], isNull);
  });

  test('every codec key has a column', () async {
    const samples = <String, Object?>{
      'name': 'Blue Hole',
      'description': 'A sinkhole',
      'latitude': 17.316,
      'longitude': -87.535,
      'min_depth_m': 5.0,
      'max_depth_m': 40.0,
      'difficulty': 'advanced',
      'water_type': 'salt',
      'country': 'Belize',
      'region': 'Lighthouse Reef',
      'city': 'Belize City',
      'island': 'Half Moon Caye',
      'body_of_water': 'Caribbean',
      'rating': 4.5,
      'notes': 'Dive early',
      'hazards': 'Depth',
      'access_notes': 'Boat only',
      'mooring_number': 'M4',
      'parking_info': 'Marina',
    };
    expect(samples.keys.toSet(), writes.fields.keys.toSet());

    await writes.update('s1', kDiverA, const RecordUpdate(values: samples));

    final doc = (await h.one('sites', 's1'))!;
    for (final MapEntry(:key, :value) in samples.entries) {
      expect(doc[key], value, reason: key);
    }
  });

  test('clearing both coordinates clears the position', () async {
    await writes.update(
      's1',
      kDiverA,
      const RecordUpdate(values: {'latitude': null, 'longitude': null}),
    );

    final doc = (await h.one('sites', 's1'))!;
    expect(doc['latitude'], isNull);
    expect(doc['longitude'], isNull);
  });

  test('one coordinate alone is blocked', () async {
    final block = await writes.refuse(
      const WriteCheck(
        kind: ChangeKind.update,
        id: 's1',
        ownerId: kDiverA,
        values: {'latitude': null},
        document: {'latitude': 17.3, 'longitude': -87.5},
      ),
    );

    expect(block?.reason, BlockReason.invalidValue);
  });

  test('create returns an id the record reads back under', () async {
    final id = await writes.create(kDiverA, {
      'name': 'Reef Wall',
      'max_depth_m': 30.0,
    });

    final doc = (await h.one('sites', id))!;
    expect(doc['name'], 'Reef Wall');
    expect(doc['max_depth_m'], 30.0);
  });

  test('delete removes the row', () async {
    await writes.delete('s1', kDiverA);

    expect(await h.one('sites', 's1'), isNull);
  });

  test('deleting another profile\'s site is refused', () async {
    expect(
      () => writes.delete('s1', kDiverB),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.writeRefused,
        ),
      ),
    );
  });

  group('a library site the owner may not edit', () {
    late SiteWrites readOnly;
    final document = {'shared_library_id': 'lib-1'};

    setUp(() {
      readOnly = SiteWrites(RecordRepositories(), stamper: _ReadOnlyStamper());
    });

    test('is refused for a library field', () async {
      final block = await readOnly.refuse(
        WriteCheck(
          kind: ChangeKind.update,
          id: 's1',
          ownerId: kDiverA,
          values: const {'name': 'Renamed'},
          document: document,
        ),
      );

      expect(block?.reason, BlockReason.notPermitted);
    });

    test('is refused for a delete', () async {
      final block = await readOnly.refuse(
        WriteCheck(
          kind: ChangeKind.delete,
          id: 's1',
          ownerId: kDiverA,
          document: document,
        ),
      );

      expect(block?.reason, BlockReason.notPermitted);
    });

    test('keeps the profile\'s own notes and rating', () async {
      final block = await readOnly.refuse(
        WriteCheck(
          kind: ChangeKind.update,
          id: 's1',
          ownerId: kDiverA,
          values: const {'notes': 'Mine', 'rating': 5.0},
          document: document,
        ),
      );

      expect(block, isNull);
    });
  });
}
