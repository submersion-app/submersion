import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain_site;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> log(
    String id, {
    int? number,
    String? name,
    String notes = '',
    DateTime? when,
    DateTime? entry,
    domain_site.DiveSite? site,
    bool planned = false,
  }) => repository.createDive(
    domain.Dive(
      id: id,
      diveNumber: number,
      name: name,
      notes: notes,
      dateTime: when ?? DateTime.utc(2026, 1, 1),
      entryTime: entry,
      site: site,
      isPlanned: planned,
    ),
  );

  Future<domain_site.DiveSite> site(String id, String name) =>
      SiteRepository().createSite(domain_site.DiveSite(id: id, name: name));

  Future<List<String>> ids({String query = '', String? diverId}) async =>
      (await repository.getDivePickerRows(
        query: query,
        diverId: diverId,
      )).map((r) => r.id).toList();

  group('order and row contents', () {
    test('lists newest first by entry time, then by dive number', () async {
      await log('old', number: 1, when: DateTime.utc(2026, 1, 1));
      await log('new', number: 2, when: DateTime.utc(2026, 3, 1));
      // The entry time decides, not the row's date: this one sorts first.
      await log(
        'entered-late',
        number: 3,
        when: DateTime.utc(2026, 2, 1),
        entry: DateTime.utc(2026, 4, 1),
      );
      await log('tied-low', number: 4, when: DateTime.utc(2026, 1, 15));
      await log('tied-high', number: 5, when: DateTime.utc(2026, 1, 15));

      expect(await ids(), [
        'entered-late',
        'new',
        'tied-high',
        'tied-low',
        'old',
      ]);
    });

    test('carries the fields a picker row shows', () async {
      final blue = await site('s1', 'Blue Corner');
      await log(
        'd1',
        number: 42,
        name: 'Drift',
        when: DateTime.utc(2026, 5, 2, 9, 30),
        site: blue,
      );

      final row = (await repository.getDivePickerRows()).single;
      expect(row.id, 'd1');
      expect(row.diveNumber, 42);
      expect(row.name, 'Drift');
      expect(row.siteName, 'Blue Corner');
      expect(row.dateTime, DateTime.utc(2026, 5, 2, 9, 30));
    });

    test('shows the dive date, not the entry time it sorts by', () async {
      await log(
        'd1',
        when: DateTime.utc(2026, 5, 2),
        entry: DateTime.utc(2026, 5, 3, 10),
      );

      final row = (await repository.getDivePickerRows()).single;
      expect(row.dateTime, DateTime.utc(2026, 5, 2));
      expect(
        row.sortTimestamp,
        DateTime.utc(2026, 5, 3, 10).millisecondsSinceEpoch,
      );
    });

    test('a dive with no number, name or site still lists', () async {
      await log('bare');

      final row = (await repository.getDivePickerRows()).single;
      expect(row.diveNumber, isNull);
      expect(row.name, isNull);
      expect(row.siteName, isNull);
    });

    test('planned dives stay in the list', () async {
      await log('plan', planned: true);

      expect(await ids(), ['plan']);
    });
  });

  group('paging', () {
    test('limit bounds the page', () async {
      for (var i = 0; i < 5; i++) {
        await log('d$i', number: i, when: DateTime.utc(2026, 1, 1 + i));
      }

      final page = await repository.getDivePickerRows(limit: 2);
      expect(page.map((r) => r.id), ['d4', 'd3']);
    });

    test('a limit of zero or below reads nothing', () async {
      await log('d1');

      // SQLite reads a negative LIMIT as no limit at all.
      expect(await repository.getDivePickerRows(limit: 0), isEmpty);
      expect(await repository.getDivePickerRows(limit: -1), isEmpty);
    });

    test('walking the cursor visits every dive once, in order', () async {
      // Ties on the timestamp, and on the number too, so the cursor has to
      // use every part of its key to neither skip nor repeat a row.
      for (var i = 0; i < 7; i++) {
        await log('d$i', number: i % 2 == 0 ? 10 : null);
      }

      final visited = <String>[];
      var page = await repository.getDivePickerRows(limit: 3);
      while (page.isNotEmpty) {
        visited.addAll(page.map((r) => r.id));
        page = await repository.getDivePickerRows(
          limit: 3,
          cursor: page.last.cursor,
        );
      }

      expect(visited, await ids());
      expect(visited.toSet(), hasLength(7));
    });

    test('the cursor pages a search too', () async {
      for (var i = 0; i < 5; i++) {
        await log('hit$i', name: 'Wreck', when: DateTime.utc(2026, 1, 1 + i));
        await log('miss$i', name: 'Reef', when: DateTime.utc(2026, 1, 1 + i));
      }

      final first = await repository.getDivePickerRows(
        query: 'wreck',
        limit: 2,
      );
      final second = await repository.getDivePickerRows(
        query: 'wreck',
        limit: 2,
        cursor: first.last.cursor,
      );

      expect(first.map((r) => r.id), ['hit4', 'hit3']);
      expect(second.map((r) => r.id), ['hit2', 'hit1']);
    });
  });

  group('search', () {
    test('matches part of the dive number', () async {
      await log('a', number: 1234);
      await log('b', number: 999);

      expect(await ids(query: '23'), ['a']);
    });

    test('matches the dive name and the site name', () async {
      final blue = await site('s1', 'Blue Corner');
      await log('named', name: 'Night Drift', when: DateTime.utc(2026, 2, 1));
      await log('sited', site: blue, when: DateTime.utc(2026, 1, 1));

      expect(await ids(query: 'night'), ['named']);
      expect(await ids(query: 'corner'), ['sited']);
    });

    test('a named dive still matches on its site', () async {
      // The row shows the name, but the picker has always matched both.
      final blue = await site('s1', 'Blue Corner');
      await log('both', name: 'Drift', site: blue);

      expect(await ids(query: 'blue'), ['both']);
    });

    test('does not reach the fields only the logbook search reads', () async {
      await log('noted', notes: 'saw a manta');

      expect(await ids(query: 'manta'), isEmpty);
    });

    test('folds accented capitals, as Dart did', () async {
      final cote = await site('s1', "CÔTE D'AZUR");
      await log('accented', name: 'ÉPAVE', site: cote);

      expect(await ids(query: 'épave'), ['accented']);
      expect(await ids(query: 'ÉPAVE'), ['accented']);
      expect(await ids(query: 'côte'), ['accented']);
    });

    test('LIKE wildcards in the term match literally', () async {
      await log('pct', name: '100% vis');
      await log('other', name: 'Murky');

      expect(await ids(query: '%'), ['pct']);
      expect(await ids(query: '_'), isEmpty);
    });

    test(
      'surrounding spaces change nothing, and only spaces is no search',
      () async {
        await log('a', name: 'Manta');
        await log('b', name: 'Reef');

        expect(await ids(query: ' manta '), ['a']);
        expect(await ids(query: '   '), hasLength(2));
      },
    );

    test('no matches is an empty page', () async {
      await log('a', name: 'Manta');

      expect(await ids(query: 'zzz'), isEmpty);
    });
  });

  group('diver scope', () {
    test('lists only the given diver', () async {
      await log('mine');

      expect(await ids(), ['mine']);
      expect(await ids(diverId: 'some-other-diver'), isEmpty);
    });

    test('a search stays inside the diver', () async {
      await log('mine', name: 'Manta');

      expect(await ids(query: 'manta', diverId: 'some-other-diver'), isEmpty);
    });
  });

  test(
    'one statement, whatever the logbook holds and whatever the row carries',
    () async {
      await tearDownTestDatabase();
      final db = AppDatabase(
        NativeDatabase.memory(
          logStatements: true,
          setup: registerAppSqlFunctions,
        ),
      );
      DatabaseService.instance.setTestDatabase(db);
      repository = DiveRepository();
      for (var i = 0; i < 6; i++) {
        await log('d$i', number: i, when: DateTime.utc(2026, 1, 1 + i));
      }

      final logged = <String>[];
      await runZoned(
        () => repository.getDivePickerRows(limit: 3),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logged.add(line),
        ),
      );

      final statements = logged.where((l) => l.startsWith('Drift: Sent'));
      expect(statements, hasLength(1));
      for (final table in [
        'dive_tanks',
        'dive_equipment',
        'dive_tags',
        'dive_dive_types',
        'dive_safety_findings',
        'trips',
      ]) {
        expect(statements.single, isNot(contains(table)));
      }
    },
  );
}
