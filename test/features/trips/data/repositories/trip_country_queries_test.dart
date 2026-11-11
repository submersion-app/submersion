import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/data/repositories/trip_country_queries.dart';
import 'package:submersion/features/trips/domain/entities/trip_country.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// A trip's flags (issue #4426) come from the countries of the same dives
/// its dive count uses: the diver's own, in the statistics scope, with a
/// larger trip counting its side trips' dives.
void main() {
  late AppDatabase db;
  late TripCountryQueries trips;

  Future<void> trip(String id, {String? parent, String? owner}) =>
      db.customStatement(
        'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
        'parent_trip_id, created_at, updated_at) '
        'VALUES (?, ?, ?, 0, 0, ?, 0, 0)',
        [id, owner, id, parent],
      );

  Future<void> site(String id, String? country, {String? code}) =>
      db.customStatement(
        'INSERT INTO dive_sites '
        '(id, name, country, country_code, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, 0, 0)',
        [id, id, country, code],
      );

  Future<void> dive(
    String id,
    String tripId,
    String siteId, {
    int at = 0,
    String? diver,
    bool planned = false,
  }) => db.customStatement(
    'INSERT INTO dives (id, diver_id, dive_date_time, trip_id, site_id, '
    'is_planned, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0, 0)',
    [id, diver, at, tripId, siteId, planned ? 1 : 0],
  );

  List<String> codes(List<TripCountry>? countries) => [
    for (final c in countries ?? const <TripCountry>[]) c.code,
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripCountryQueries();
    await site('cozumel', 'Mexico');
    await site('cancun', 'México');
    await site('belize', 'Belize');
    await site('atlantis', 'Atlantis');
    await site('dahab', 'Egypt');
  });
  tearDown(tearDownTestDatabase);

  test('countries order by dive count, most first', () async {
    await trip('T');
    await dive('a', 'T', 'belize', at: 1);
    await dive('b', 'T', 'cozumel', at: 2);
    await dive('c', 'T', 'cozumel', at: 3);
    await dive('d', 'T', 'cozumel', at: 4);

    final countries = await trips.getTripCountries();
    expect(codes(countries['T']), ['MX', 'BZ']);
  });

  test('names that mean one country merge into one flag', () async {
    await trip('T');
    await dive('a', 'T', 'cozumel');
    await dive('b', 'T', 'cancun');

    final countries = (await trips.getTripCountries())['T']!;
    expect(codes(countries), ['MX']);
    expect(countries.single.name, isIn(['Mexico', 'México']));
  });

  test('on a tie between spellings the one dived first names it', () async {
    await trip('T');
    await dive('a', 'T', 'cozumel', at: 9); // "Mexico"
    await dive('b', 'T', 'cancun', at: 1); // "México", dived first

    final countries = (await trips.getTripCountries())['T']!;
    expect(countries.single.name, 'México');
  });

  test('a stored code counts for text the table cannot read', () async {
    await site('munseom', 'Korea', code: 'KR');
    await trip('T');
    await dive('a', 'T', 'munseom');

    final countries = (await trips.getTripCountries())['T']!;
    expect(countries.single, const TripCountry(code: 'KR', name: 'Korea'));
  });

  test('a site with only a stored code still counts', () async {
    await site('nameless', null, code: 'KR');
    await trip('T');
    await dive('a', 'T', 'nameless');

    final countries = (await trips.getTripCountries())['T']!;
    expect(countries.single, const TripCountry(code: 'KR', name: 'KR'));
  });

  test('blank country text with a stored code is named by the code', () async {
    await site('blank', '   ', code: 'KR');
    await trip('T');
    await dive('a', 'T', 'blank');

    final countries = (await trips.getTripCountries())['T']!;
    expect(countries.single, const TripCountry(code: 'KR', name: 'KR'));
  });

  test('a country it cannot name adds nothing', () async {
    await trip('T');
    await dive('a', 'T', 'atlantis');

    expect(codes((await trips.getTripCountries())['T']), isEmpty);
  });

  test('a tie goes to the country dived first', () async {
    await trip('T');
    await dive('a', 'T', 'belize', at: 10);
    await dive('b', 'T', 'cozumel', at: 5);

    expect(codes((await trips.getTripCountries())['T']), ['MX', 'BZ']);
  });

  test('a larger trip includes its side trips countries', () async {
    await trip('P');
    await trip('S', parent: 'P');
    await dive('a', 'P', 'cozumel');
    await dive('b', 'S', 'belize');

    final countries = await trips.getTripCountries();
    expect(codes(countries['P']), unorderedEquals(['MX', 'BZ']));
    expect(codes(countries['S']), ['BZ']);
  });

  test('on a shared trip only the diver own dives count', () async {
    for (final id in ['me', 'buddy']) {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        'VALUES (?, ?, 0, 0)',
        [id, id],
      );
    }
    await trip('T', owner: 'me');
    await dive('a', 'T', 'cozumel', diver: 'me');
    await dive('b', 'T', 'dahab', diver: 'buddy');

    final mine = await trips.getTripCountries(diverId: 'me');
    expect(codes(mine['T']), ['MX']);
  });

  test('a dive outside the statistics scope adds nothing', () async {
    await trip('T');
    await dive('a', 'T', 'cozumel');
    await dive('b', 'T', 'dahab', planned: true);

    expect(codes((await trips.getTripCountries())['T']), ['MX']);
  });

  test('a trip with no dives has no entry', () async {
    await trip('T');
    expect((await trips.getTripCountries())['T'], isNull);
  });

  test('a failing read is reported to the caller, not swallowed', () async {
    await db.customStatement('DROP TABLE dive_sites');

    await expectLater(trips.getTripCountries(), throwsA(anything));
  });

  test('a trip hidden from the diver reads nothing for them', () async {
    await seedDivers(db, ['b', 'c']);
    await seedTrip(db, 'shared', owner: 'c', shared: true, name: 'Cozumel');
    await dive('b1', 'shared', 'cozumel', diver: 'b');
    await dive('c1', 'shared', 'cozumel', diver: 'c');
    await ProfileHidesRepository().hide(SharedItemKind.trip, 'shared', 'b');

    expect((await trips.getTripCountries(diverId: 'b'))['shared'], isNull);
    expect(codes((await trips.getTripCountries(diverId: 'c'))['shared']), [
      'MX',
    ]);
  });
}
