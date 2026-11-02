import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
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

    test('a second regulator on a tank counts', () async {
      await insertDive('tanked');
      await insertDive('other');
      await insertGear('g1', name: 'Pony reg', brand: 'Poseidon');
      await sql(
        'INSERT INTO dive_tanks (id, dive_id, extra_regulator_ids) '
        'VALUES (?, ?, ?)',
        ['t1', 'tanked', '["g1"]'],
      );

      expect(await found('poseidon'), ['tanked']);
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

    test('a negated word keeps a dive with no trip or computer', () async {
      await sql(
        'INSERT INTO trips (id, name, start_date, end_date, created_at, '
        'updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        ['trip', 'Lofoten', stamp, stamp, stamp, stamp],
      );
      await insertDive('on-trip', tripId: 'trip');
      await insertDive('bare');

      expect(await found('not lofoten'), ['bare']);
      expect(await found('not perdix'), unorderedEquals(['on-trip', 'bare']));
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

  Future<void> insertSite(
    String id,
    String name, {
    String? country,
    String? waterType,
    String? entryMethod,
  }) => sql(
    'INSERT INTO dive_sites (id, name, country, water_type, entry_method, '
    'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [id, name, country, waterType, entryMethod, stamp, stamp],
  );

  Future<void> patchDive(String id, String column, Object? value) =>
      sql('UPDATE dives SET $column = ? WHERE id = ?', [value, id]);

  Future<void> insertTank(String id, String diveId, double o2, double he) =>
      sql(
        'INSERT INTO dive_tanks (id, dive_id, o2_percent, he_percent) '
        'VALUES (?, ?, ?, ?)',
        [id, diveId, o2, he],
      );

  group('the searches from the issue', () {
    setUp(() async {
      await insertSite('ressel', 'Ressel', country: 'France');
      await insertSite('pier', 'Salt Pier', country: 'Bonaire');
      await insertDive('oct', date: DateTime(2018, 10, 14));
      await patchDive('oct', 'site_id', 'ressel');
      await insertDive('mar', date: DateTime(2018, 3, 2));
      await patchDive('mar', 'site_id', 'ressel');
      await patchDive('mar', 'buddy', 'Mike');
      await insertDive('later', date: DateTime(2019, 10, 14));
      await patchDive('later', 'site_id', 'ressel');
      await insertDive('away', date: DateTime(2018, 10, 20));
      await patchDive('away', 'site_id', 'pier');
    });

    test('a site, a month and a year', () async {
      expect(await found('ressel october 2018'), ['oct']);
    });

    test('a country, a month and a year', () async {
      expect(await found('france october 2018'), ['oct']);
    });

    test('a site in a year', () async {
      expect(await found('ressel in 2018'), unorderedEquals(['oct', 'mar']));
    });

    test('a site with a buddy', () async {
      expect(await found('ressel with mike'), ['mar']);
    });

    test('the whole sentence', () async {
      expect(await found('dives in the ressel in 2018 with mike'), ['mar']);
    });
  });

  group('words that stand for a value', () {
    test('a year finds its dives, the notes and the dive number', () async {
      await insertDive('in-year', date: DateTime(2018, 5, 1));
      await insertDive('in-notes', date: DateTime(2021, 5, 1));
      await patchDive('in-notes', 'notes', 'Back here since 2018');
      await insertDive('numbered', date: DateTime(2021, 5, 2));
      await patchDive('numbered', 'dive_number', 2018);
      await insertDive('other', date: DateTime(2021, 5, 3));

      expect(
        await found('2018'),
        unorderedEquals(['in-year', 'in-notes', 'numbered']),
      );
    });

    test('a month name finds that month of any year', () async {
      await insertDive('one', date: DateTime(2018, 10, 1));
      await insertDive('two', date: DateTime(2021, 10, 31));
      await insertDive('other', date: DateTime(2021, 11, 1));

      expect(await found('october'), unorderedEquals(['one', 'two']));
      expect(await found('octobre'), unorderedEquals(['one', 'two']));
    });

    test('a month name that is also a buddy finds both', () async {
      await insertDive('in-june', date: DateTime(2021, 6, 2));
      await insertDive('with-june', date: DateTime(2021, 7, 2));
      await patchDive('with-june', 'buddy', 'June');
      await insertDive('other', date: DateTime(2021, 8, 2));

      expect(await found('june'), unorderedEquals(['in-june', 'with-june']));
    });

    test('a short month alone finds a buddy, not the month', () async {
      await insertDive('in-jan', date: DateTime(2021, 1, 2));
      await insertDive('with-jan', date: DateTime(2021, 7, 2));
      await patchDive('with-jan', 'buddy', 'Jan');

      expect(await found('jan'), ['with-jan']);
      expect(await found('jan 2021'), ['in-jan']);
    });

    test('a weekday finds its dives', () async {
      await insertDive('saturday', date: DateTime(2026, 10, 31));
      await insertDive('sunday', date: DateTime(2026, 11, 1));

      expect(await found('saturday'), ['saturday']);
    });

    test('a dive mode', () async {
      await insertDive('loop');
      await patchDive('loop', 'dive_mode', 'ccr');
      await insertDive('open');

      expect(await found('ccr'), ['loop']);
      expect(await found('rebreather'), ['loop']);
      expect(await found('closed circuit rebreather'), ['loop']);
    });

    test('an entry or exit method', () async {
      await insertDive('in');
      await patchDive('in', 'entry_method', 'shore');
      await insertDive('out');
      await patchDive('out', 'exit_method', 'shore');
      await insertDive('roll');
      await patchDive('roll', 'entry_method', 'backRoll');

      expect(await found('shore'), unorderedEquals(['in', 'out']));
      expect(await found('back roll'), ['roll']);
    });

    test('entry follows the site when the dive has none', () async {
      await insertSite('jetty', 'Town', entryMethod: 'shore');
      await insertDive('at-site');
      await patchDive('at-site', 'site_id', 'jetty');

      expect(await found('shore'), ['at-site']);
    });

    test('water type follows the site when the dive has none', () async {
      await insertSite('lake', 'Lake', waterType: 'fresh');
      await insertDive('at-site');
      await patchDive('at-site', 'site_id', 'lake');
      await insertDive('sea');
      await patchDive('sea', 'water_type', 'salt');

      expect(await found('fresh water'), ['at-site']);
      expect(await found('saltwater'), ['sea']);
    });

    test('a gas word reads the mix, not the oxygen alone', () async {
      await insertDive('air');
      await insertTank('t1', 'air', 21, 0);
      await insertDive('ean32');
      await insertTank('t2', 'ean32', 32, 0);
      await insertDive('tx');
      await insertTank('t3', 'tx', 21, 35);
      await insertDive('rich-tx');
      await insertTank('t4', 'rich-tx', 32, 10);

      expect(await found('air'), ['air']);
      expect(await found('nitrox'), ['ean32']);
      expect(await found('trimix'), unorderedEquals(['tx', 'rich-tx']));
      expect(await found('ean32'), ['ean32']);
    });

    test('a favourite', () async {
      await insertDive('liked');
      await patchDive('liked', 'is_favorite', 1);
      await insertDive('other');

      expect(await found('favourite'), ['liked']);
      expect(await found('favorite'), ['liked']);
    });

    test('a word that is a field reads as plain words before in', () async {
      await insertDive('liked', date: DateTime(2018, 5, 1));
      await patchDive('liked', 'is_favorite', 1);
      await insertDive('liked-later', date: DateTime(2019, 5, 1));
      await patchDive('liked-later', 'is_favorite', 1);

      expect(await found('favorite in 2018'), ['liked']);
    });

    test('a negated word keeps a dive with no value', () async {
      await insertDive('walked');
      await patchDive('walked', 'entry_method', 'shore');
      await insertDive('unset');

      expect(await found('not shore'), ['unset']);
    });
  });
}
