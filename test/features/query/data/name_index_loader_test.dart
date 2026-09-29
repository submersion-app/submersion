import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/test_database.dart';
import '../../dive_log/query/dive_query_fixture.dart';

final _en = l10nForLocaleTag('en');

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  Future<NameIndex> load({String? diverId = 'me'}) =>
      NameIndexLoader(db).load(diverId: diverId, l10n: _en);

  test('places merge sites by label and remember their columns', () async {
    final index = await load();
    final bonaire = index
        .forSubject(QuerySubject.sites)
        .singleWhere(
          (e) => e.target == NameTarget.sitePlace && e.label == 'Bonaire',
        );
    expect(bonaire.ids.toSet(), {'s1', 's2'});
    expect(bonaire.placeFields, ['country']);
    expect(bonaire.rank, 0);
  });

  test('a legacy buddy name is a sentence-only buddy entry', () async {
    final index = await load();
    final bob = index
        .forSubject(QuerySubject.buddies)
        .singleWhere((e) => e.target == NameTarget.legacyBuddyName);
    expect(bob.label, 'Bob');
    expect(bob.rank, 1);
    expect(index.resolve(QuerySubject.buddies, 'Bob'), isNull);
  });

  test('an item\'s brand and model is an alternate label', () async {
    await db.customStatement(
      "UPDATE equipment SET brand = 'Apeks', model = 'XTX50' WHERE id = 'g_bcd'",
    );
    final index = await load();
    expect(
      index.resolve(QuerySubject.equipment, 'apeks xtx50'),
      const RefValue('g_bcd', 'g_bcd'),
    );
  });

  test('a built-in species gets its localized name as an alternate', () async {
    // The test database seeds no catalog, so insert one built-in species
    // whose id the name lookup knows.
    await db.customStatement(
      "INSERT INTO species (id, common_name, category, is_built_in) "
      "VALUES ('sp_whale_shark', 'Whale Shark', 'fish', 1)",
    );
    final de = l10nForLocaleTag('de');
    final index = await NameIndexLoader(db).load(diverId: 'me', l10n: de);
    final german = de.species_whale_shark_name;
    expect(german, isNot('Whale Shark'));
    final alternate = index
        .forSubject(QuerySubject.species)
        .singleWhere((e) => e.label == german);
    expect(alternate.primary, isFalse);
    expect(alternate.rank, 0);
    expect(
      index.resolve(QuerySubject.species, german),
      const RefValue('sp_whale_shark', 'Whale Shark'),
    );
  });

  test('every curated choice attribute choice is a gear entry', () async {
    final index = await load();
    final choices = index
        .forSubject(QuerySubject.equipment)
        .where((e) => e.target == NameTarget.attrChoice);
    expect(choices, isNotEmpty);
    expect(
      choices.every((e) => e.attrKey != null && e.attrChoice != null),
      isTrue,
    );
  });

  test(
    'loads every ref subject, scoped to the diver plus unowned rows',
    () async {
      final index = await NameIndexLoader(db).load(diverId: 'me', l10n: _en);
      expect(
        index.refs(QuerySubject.sites).map((r) => r.label),
        containsAll(['Salt Pier', 'Hilma Hooker', 'Cenote']),
      );
      expect(
        index.refs(QuerySubject.buddies).map((r) => r.id),
        containsAll(['b1', 'b2']),
      );
      expect(index.resolve(QuerySubject.sites, 'cenote')?.id, 's3');
      // Every subject answers, even with no rows.
      for (final s in NameIndexLoader.refSubjects) {
        expect(index.refs(s), isA<List<RefValue>>());
      }
    },
  );

  test('another diver\'s private rows stay out of the index', () async {
    final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO buddies (id, diver_id, name, created_at, updated_at) "
      "VALUES ('b-other', 'other', 'Zed', $now, $now)",
    );
    final index = await NameIndexLoader(db).load(diverId: 'me', l10n: _en);
    expect(index.labelOf(QuerySubject.buddies, 'b-other'), isNull);
    final theirs = await NameIndexLoader(db).load(diverId: 'other', l10n: _en);
    expect(theirs.labelOf(QuerySubject.buddies, 'b-other'), 'Zed');
  });

  test('rows another diver shares are in the index, like the lists', () async {
    final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;
    // Shared with every profile by flag (sites and trips) or with one
    // profile by a share row (equipment), as VisibilityFilter reads them.
    await db.customStatement(
      "INSERT INTO dive_sites (id, diver_id, name, is_shared, created_at, "
      "updated_at) VALUES ('s-shared', 'other', 'Blue Hole', 1, $now, $now), "
      "('s-private', 'other', 'Secret Reef', 0, $now, $now)",
    );
    await db.customStatement(
      "INSERT INTO trips (id, diver_id, name, start_date, end_date, "
      "is_shared, created_at, updated_at) VALUES ('t-shared', 'other', "
      "'Club Trip', $now, $now, 1, $now, $now)",
    );
    await db.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('g-lent', 'other', 'Loaner BCD', 'bcd', $now, "
      "$now)",
    );
    await db.customStatement(
      "INSERT INTO equipment_shares (id, equipment_id, diver_id, "
      "created_at) VALUES ('sh1', 'g-lent', 'me', $now)",
    );
    final index = await NameIndexLoader(db).load(diverId: 'me', l10n: _en);
    expect(index.resolve(QuerySubject.sites, 'blue hole')?.id, 's-shared');
    expect(index.labelOf(QuerySubject.sites, 's-private'), isNull);
    expect(index.resolve(QuerySubject.trips, 'club trip')?.id, 't-shared');
    expect(index.resolve(QuerySubject.equipment, 'loaner bcd')?.id, 'g-lent');
  });

  test('the tables it reads are the ref tables, the share table and dives', () {
    expect(NameIndexLoader.tables, {
      'equipment_shares',
      'dives',
      'site_types',
      'dive_sites',
      'trips',
      'dive_centers',
      'dive_computers',
      'courses',
      'buddies',
      'tags',
      'dive_types',
      'equipment',
      'species',
    });
  });

  test('a site with no place fields contributes no place entry', () async {
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s-bare', 'Bare Reef', 0, 0)",
    );
    final index = await load();
    final places = index
        .forSubject(QuerySubject.sites)
        .where((e) => e.target == NameTarget.sitePlace);
    expect(places.any((e) => e.ids.contains('s-bare')), isFalse);
    expect(index.resolve(QuerySubject.sites, 'Bare Reef')?.id, 's-bare');
  });

  test('tags, centers, trips and computers each get a row', () async {
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('t1', 'night', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_centers (id, name, created_at, updated_at) "
      "VALUES ('c1', 'Buddy Dive', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO trips (id, name, start_date, end_date, created_at, "
      "updated_at) VALUES ('tr1', 'Bonaire 2025', 0, 0, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_computers (id, name, created_at, updated_at) "
      "VALUES ('dc1', 'Perdix', 0, 0)",
    );
    final index = await load();
    expect(index.resolve(QuerySubject.tags, 'night')?.id, 't1');
    expect(index.resolve(QuerySubject.centers, 'buddy dive')?.id, 'c1');
    expect(index.resolve(QuerySubject.trips, 'Bonaire 2025')?.id, 'tr1');
    expect(index.resolve(QuerySubject.computers, 'perdix')?.id, 'dc1');
  });
}
