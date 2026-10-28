import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/data/repositories/selection_trip_facts.dart';

import '../../../../helpers/test_database.dart';

/// What the new-trip form reads from the selected dives (issue #3658).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, region, country, created_at, "
      "updated_at) VALUES ('s1', 'Cape Kri', 'Raja Ampat', 'Indonesia', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_centers (id, name, created_at, updated_at) "
      "VALUES ('c1', 'Kri Eco', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO trips (id, name, start_date, end_date, created_at, "
      "updated_at) VALUES ('t1', 'Indonesia', 0, 0, 0, 0)",
    );
    for (final (id, at, site, center, trip) in [
      ('d1', 1000, 's1', 'c1', 't1'),
      ('d2', 2000, null, null, null),
      ('d3', 3000, 's1', null, 't1'),
    ]) {
      await db.customStatement(
        'INSERT INTO dives (id, dive_date_time, site_id, dive_center_id, '
        'trip_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 0, 0)',
        [id, at, site, center, trip],
      );
    }
  });
  tearDown(tearDownTestDatabase);

  test('reads each selected dive with its site, center and trip', () async {
    final facts = {
      for (final f in await selectionTripFacts(db, ['d1', 'd2'])) f.diveId: f,
    };
    expect(facts.keys, unorderedEquals(['d1', 'd2']));
    final d1 = facts['d1']!;
    expect(
      d1.diveDateTime,
      DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
    expect(d1.siteRegion, 'Raja Ampat');
    expect(d1.siteCountry, 'Indonesia');
    expect(d1.diveCenterName, 'Kri Eco');
    expect(d1.tripId, 't1');
    final d2 = facts['d2']!;
    expect(d2.siteRegion, isNull);
    expect(d2.tripId, isNull);
  });

  test('a long selection is read in chunks', () async {
    final ids = [for (var i = 0; i < 1200; i++) 'x$i', 'd3'];
    final facts = await selectionTripFacts(db, ids);
    expect(facts.map((f) => f.diveId), ['d3']);
  });
}
