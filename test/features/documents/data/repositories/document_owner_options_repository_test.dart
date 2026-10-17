import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/data/repositories/document_owner_options_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DocumentOwnerOptionsRepository repo;

  setUp(() async {
    final db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0), ('d2', 'Ben', 0, 0, 0)",
    );
    await sql(
      'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
      "created_at, updated_at) VALUES ('t1', 'd1', 'Bonaire', 0, 0, 0, 0), "
      "('t2', 'd1', 'Red Sea', 1000, 1000, 0, 0), "
      "('t3', 'd2', 'Not mine', 0, 0, 0, 0)",
    );
    await sql(
      'INSERT INTO equipment (id, diver_id, name, brand, model, type, '
      "created_at, updated_at) VALUES ('e1', 'd1', 'Regulator', 'Apeks', "
      "'XTX50', 'regulator', 0, 0), ('e2', 'd1', 'Regulator', NULL, NULL, "
      "'regulator', 0, 0)",
    );
    await sql(
      'INSERT INTO dive_sites (id, diver_id, name, shared_library_id, '
      "created_at, updated_at) VALUES ('s1', 'd1', 'Salt Pier', NULL, 0, 0), "
      "('s2', 'd1', 'Club wreck', 'lib1', 0, 0)",
    );
    final when = DateTime.utc(2026, 9, 1, 9).millisecondsSinceEpoch;
    await sql(
      'INSERT INTO dives (id, diver_id, dive_number, dive_date_time, site_id, '
      "created_at, updated_at) VALUES ('v1', 'd1', 12, $when, 's1', 0, 0)",
    );
    await sql(
      'INSERT INTO dives (id, diver_id, dive_number, dive_date_time, site_id, '
      "name, created_at, updated_at) VALUES ('v2', 'd2', 7, $when, 's1', "
      "'Night at the pier', 0, 0), ('v3', 'd2', NULL, $when, NULL, '  ', "
      '0, 0)',
    );
    await sql(
      'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
      "VALUES ('b1', 'd1', 'zoe', 0, 0), ('b2', 'd1', 'Adam', 0, 0)",
    );
    await sql(
      'INSERT INTO certifications (id, diver_id, name, agency, level, '
      "created_at, updated_at) VALUES ('c1', 'd1', '', 'padi', "
      "'advancedNitrox', 0, 0), ('c2', 'd1', 'Adv. Nitrox', 'padi', "
      "'advancedNitrox', 0, 0)",
    );
    repo = DocumentOwnerOptionsRepository();
  });
  tearDown(tearDownTestDatabase);

  test("lists the diver's trips, latest first", () async {
    final trips = await repo.optionsFor(DocumentOwnerKind.trip, diverId: 'd1');
    expect(trips.map((o) => o.label), ['Red Sea', 'Bonaire']);
    expect(trips.map((o) => o.id), ['t2', 't1']);
  });

  test('trips carry their start date and gear its make', () async {
    final trips = await repo.optionsFor(DocumentOwnerKind.trip, diverId: 'd1');
    expect(trips.first.date, DateTime.fromMillisecondsSinceEpoch(1000));
    final gear = await repo.optionsFor(
      DocumentOwnerKind.equipment,
      diverId: 'd1',
    );
    expect(gear.map((o) => o.subtitle), unorderedEquals(['Apeks XTX50', null]));
  });

  test('names sort without regard to case', () async {
    final buddies = await repo.optionsFor(
      DocumentOwnerKind.buddy,
      diverId: 'd1',
    );
    expect(buddies.map((o) => o.label), ['Adam', 'zoe']);
  });

  test('a dive reads its number, site and wall-clock date', () async {
    final dives = await repo.optionsFor(DocumentOwnerKind.dive, diverId: 'd1');
    expect(dives.single.label, '#12');
    expect(dives.single.subtitle, 'Salt Pier');
    expect(dives.single.date, DateTime.utc(2026, 9, 1, 9));
  });

  test('a named dive is told apart by its name, else by its site', () async {
    final dives = await repo.optionsFor(DocumentOwnerKind.dive, diverId: 'd2');
    final byId = {for (final o in dives) o.id: o};
    expect(byId['v2']!.label, '#7');
    expect(byId['v2']!.subtitle, 'Night at the pier');
    // A blank name is no name, and with no site there is nothing to show.
    expect(byId['v3']!.label, '');
    expect(byId['v3']!.subtitle, isNull);
  });

  // Issue #3366: a certification with no custom title stores an empty name,
  // so the option carries what its title is derived from.
  test('a certification carries the fields its title is made from', () async {
    final certs = await repo.optionsFor(
      DocumentOwnerKind.certification,
      diverId: 'd1',
    );
    expect(certs.map((o) => o.id), unorderedEquals(['c1', 'c2']));
    final plain = certs.firstWhere((o) => o.id == 'c1');
    expect(plain.certification, (
      name: '',
      agency: 'padi',
      level: 'advancedNitrox',
    ));
    final trip = (await repo.optionsFor(
      DocumentOwnerKind.trip,
      diverId: 'd1',
    )).first;
    expect(trip.certification, isNull);
  });

  test(
    'certificationFieldsFor reads a certification and is null when gone',
    () async {
      expect(await repo.certificationFieldsFor('c1'), (
        name: '',
        agency: 'padi',
        level: 'advancedNitrox',
      ));
      expect(await repo.certificationFieldsFor('gone'), isNull);
    },
  );

  test('club library sites are not offered', () async {
    final sites = await repo.optionsFor(DocumentOwnerKind.site, diverId: 'd1');
    expect(sites.map((o) => o.label), ['Salt Pier']);
  });

  test('personal has no options', () async {
    expect(
      await repo.optionsFor(DocumentOwnerKind.personal, diverId: 'd1'),
      isEmpty,
    );
  });

  test(
    'optionFor names a record and is null for personal or a gone one',
    () async {
      final trip = await repo.optionFor(
        const DocumentOwner(DocumentOwnerKind.trip, 't1'),
      );
      expect(trip!.label, 'Bonaire');
      expect(trip.date, isNull);
      expect(await repo.optionFor(const DocumentOwner.personal()), isNull);
      expect(
        await repo.optionFor(
          const DocumentOwner(DocumentOwnerKind.trip, 'gone'),
        ),
        isNull,
      );
      expect(
        await repo.optionFor(
          const DocumentOwner(DocumentOwnerKind.dive, 'gone'),
        ),
        isNull,
      );
    },
  );

  test('optionFor describes a dive as the picker lists it (#3391)', () async {
    final dive = await repo.optionFor(
      const DocumentOwner(DocumentOwnerKind.dive, 'v1'),
    );
    expect(dive!.label, '#12');
    expect(dive.subtitle, 'Salt Pier');
    expect(dive.date, DateTime.utc(2026, 9, 1, 9));
    expect(dive.name, '#12 · Salt Pier');
    final named = await repo.optionFor(
      const DocumentOwner(DocumentOwnerKind.dive, 'v2'),
    );
    expect(named!.name, '#7 · Night at the pier');
  });
}
