import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/query_tables_touched.dart';

import '../../../../helpers/test_database.dart';

/// What a word typed in the dive search finds, read through the same parser
/// and repository call the list uses (#3457).
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  final stamp = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> sql(String statement, [List<Object?> args = const []]) =>
      db.customStatement(statement, args);

  Future<void> insertDive(
    String id, {
    DateTime? date,
    String? tripId,
    String? computerId,
    String? computerModel,
  }) => sql(
    'INSERT INTO dives (id, dive_date_time, created_at, updated_at, trip_id, '
    'computer_id, dive_computer_model) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [
      id,
      DateTime.utc(
        date?.year ?? 2026,
        date?.month ?? 6,
        date?.day ?? 1,
      ).millisecondsSinceEpoch,
      stamp,
      stamp,
      tripId,
      computerId,
      computerModel,
    ],
  );

  Future<void> insertGear(
    String id, {
    required String name,
    String? brand,
    String? model,
  }) => sql(
    'INSERT INTO equipment (id, name, type, brand, model, created_at, '
    "updated_at) VALUES (?, ?, 'regulator', ?, ?, ?, ?)",
    [id, name, brand, model, stamp, stamp],
  );

  Future<void> linkGear(String diveId, String gearId) => sql(
    'INSERT INTO dive_equipment (dive_id, equipment_id) VALUES (?, ?)',
    [diveId, gearId],
  );

  Future<List<String>> found(String text) async {
    final parsed = QueryParser(
      appQueryRegistry,
      diveQueryEntity,
      ParseContext(
        prefs: kMetricPrefs,
        now: DateTime(2026, 6, 1),
        names: NameIndex.empty,
      ),
    ).parse(text);
    final node = (parsed as ParseOk).node!;
    final dives = await repo.getDiveSummaries(
      filter: DiveFilterState(query: node),
    );
    return [for (final d in dives) d.id];
  }

  group('records attached to a dive', () {
    test('a gear brand, model or name finds the dive', () async {
      await insertDive('with-gear');
      await insertDive('other');
      await insertGear('g1', name: 'My old reg', brand: 'Apeks', model: 'MTX');
      await linkGear('with-gear', 'g1');

      expect(await found('apeks'), ['with-gear']);
      expect(await found('mtx'), ['with-gear']);
      expect(await found('"old reg"'), ['with-gear']);
    });

    test('gear on a tank counts', () async {
      await insertDive('tanked');
      await insertDive('other');
      await insertGear('g1', name: 'Cylinder', brand: 'Faber');
      await sql(
        'INSERT INTO dive_tanks (id, dive_id, equipment_id) VALUES (?, ?, ?)',
        ['t1', 'tanked', 'g1'],
      );

      expect(await found('faber'), ['tanked']);
    });

    test('a regulator on a tank counts', () async {
      await insertDive('tanked');
      await insertDive('other');
      await insertGear('g1', name: 'First stage', brand: 'Scubapro');
      await sql(
        'INSERT INTO dive_tanks (id, dive_id, regulator_equipment_id) '
        'VALUES (?, ?, ?)',
        ['t1', 'tanked', 'g1'],
      );

      expect(await found('scubapro'), ['tanked']);
    });

    test('a trip name, location, resort or boat finds the dive', () async {
      await sql(
        'INSERT INTO trips (id, name, start_date, end_date, location, '
        'resort_name, liveaboard_name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'trip',
          'Lofoten week',
          stamp,
          stamp,
          'Norway',
          'Arctic Lodge',
          'Polar Star',
          stamp,
          stamp,
        ],
      );
      await insertDive('on-trip', tripId: 'trip');
      await insertDive('other');

      expect(await found('lofoten'), ['on-trip']);
      expect(await found('norway'), ['on-trip']);
      expect(await found('arctic'), ['on-trip']);
      expect(await found('polar'), ['on-trip']);
    });

    test('a sighted species finds the dive', () async {
      await insertDive('seen');
      await insertDive('other');
      await sql(
        'INSERT INTO species (id, common_name, scientific_name, category) '
        "VALUES (?, ?, ?, 'turtle')",
        ['sp', 'Green turtle', 'Chelonia mydas'],
      );
      await sql(
        'INSERT INTO sightings (id, dive_id, species_id) VALUES (?, ?, ?)',
        ['s1', 'seen', 'sp'],
      );

      expect(await found('turtle'), ['seen']);
      expect(await found('chelonia'), ['seen']);
    });

    test('a built-in species finds the dive in another language', () async {
      await insertDive('seen');
      await insertDive('other');
      await sql(
        'INSERT OR IGNORE INTO species (id, common_name, category, '
        "is_built_in) VALUES (?, ?, 'shark', 1)",
        ['sp_whale_shark', 'Whale Shark'],
      );
      await sql(
        'INSERT INTO sightings (id, dive_id, species_id) VALUES (?, ?, ?)',
        ['s1', 'seen', 'sp_whale_shark'],
      );

      expect(await found('walhai'), ['seen']);
    });

    test('a course name finds the dive', () async {
      await insertDive('training');
      await insertDive('other');
      await sql(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?)',
        ['diver', 'Test', stamp, stamp],
      );
      await sql(
        'INSERT INTO courses (id, diver_id, name, agency, start_date, '
        "location, created_at, updated_at) VALUES (?, ?, ?, 'padi', ?, ?, ?, ?)",
        ['c1', 'diver', 'Rescue Diver', stamp, 'Dahab', stamp, stamp],
      );
      await sql(
        'INSERT INTO dive_courses (id, dive_id, course_id, created_at) '
        'VALUES (?, ?, ?, ?)',
        ['dc1', 'training', 'c1', stamp],
      );

      expect(await found('rescue'), ['training']);
      expect(await found('dahab'), ['training']);
    });

    test('a computer name, maker or model finds the dive', () async {
      await sql(
        'INSERT INTO dive_computers (id, name, manufacturer, model, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        ['dc', 'Wrist unit', 'Shearwater', 'Perdix', stamp, stamp],
      );
      await insertDive('logged', computerId: 'dc');
      await insertDive('imported', computerModel: 'Teric');
      await insertDive('other');

      expect(await found('shearwater'), ['logged']);
      expect(await found('perdix'), ['logged']);
      expect(await found('wrist'), ['logged']);
      expect(await found('teric'), ['imported']);
    });

    test('a negated word keeps a dive with nothing attached', () async {
      await insertDive('bare');
      await insertDive('with-gear');
      await insertGear('g1', name: 'Reg', brand: 'Shearwater');
      await linkGear('with-gear', 'g1');

      expect(await found('not shearwater'), ['bare']);
    });

    test('a search reads every attached table, so a write refreshes it', () {
      final node =
          (QueryParser(
                    appQueryRegistry,
                    diveQueryEntity,
                    ParseContext(
                      prefs: kMetricPrefs,
                      now: DateTime(2026, 6, 1),
                      names: NameIndex.empty,
                    ),
                  ).parse('apeks')
                  as ParseOk)
              .node;

      expect(
        tablesTouchedOrRoot(node, diveQueryEntity),
        containsAll([
          'equipment',
          'dive_equipment',
          'dive_tanks',
          'trips',
          'sightings',
          'species',
          'dive_courses',
          'courses',
          'dive_computers',
        ]),
      );
    });
  });
}
