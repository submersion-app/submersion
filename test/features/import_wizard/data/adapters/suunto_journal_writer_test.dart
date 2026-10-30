import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_journal.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_journal_writer.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/core/constants/enums.dart' show SpeciesCategory;

import '../../../../helpers/test_database.dart';

/// Issue #3491: what the diver logged in the Suunto app's dive details fills
/// the imported dive, only where the dive has nothing of that kind.
void main() {
  late AppDatabase db;
  late SuuntoJournalWriter writer;

  const diverId = 'diver-1';

  SuuntoJournal fixtureJournal() {
    final body = File(
      p.join(
        'test',
        'fixtures',
        'suunto_cloud',
        'workout_journal_buddies.json',
      ),
    ).readAsStringSync();
    final payload = (jsonDecode(body) as Map)['payload'] as List;
    return SuuntoJournal.parse((payload.single as Map)['journal']);
  }

  SuuntoParsedDive parsed([SuuntoJournal? journal]) => SuuntoParsedDive(
    dive: DownloadedDive(
      startTime: DateTime.utc(2026, 10, 7, 17, 39, 17),
      durationSeconds: 2340,
      maxDepth: 7.3,
      profile: const [],
    ),
    deviceName: 'Suunto Nautic',
    serialNumber: 'NS-1',
    journal: journal ?? fixtureJournal(),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$diverId', 'Me', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
      "updated_at) VALUES ('d1', '$diverId', 1000, 1000, 1000)",
    );
    writer = SuuntoJournalWriter();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Map<String, Object?>> dive() async =>
      (await db.customSelect("SELECT * FROM dives WHERE id = 'd1'").getSingle())
          .data;

  Future<List<Map<String, Object?>>> rows(String sql) async => [
    for (final row in await db.customSelect(sql).get()) row.data,
  ];

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  Future<void> attach({VisibilityScale scale = VisibilityScale.tropical}) =>
      writer.attach('d1', parsed(), diverId, scale: scale);

  test('fills an empty dive from the real workout', () async {
    await attach();

    final row = await dive();
    final center = (await rows(
      'SELECT name, diver_id FROM dive_centers',
    )).single;
    expect(center, {'name': 'Dive Center', 'diver_id': diverId});
    expect(row['dive_center_id'], isNotNull);

    final good = VisibilityScale.tropical.rangeFor(VisibilityBand.good);
    expect(row['visibility_min_meters'], good.minM);
    expect(row['visibility_max_meters'], good.maxM);
    expect(row['visibility'], isNull);
    expect(row['current_strength'], 'none');

    expect(
      await rows(
        "SELECT weight_type, amount_kg FROM dive_weights WHERE dive_id = 'd1'",
      ),
      [
        {'weight_type': 'belt', 'amount_kg': 12.0},
      ],
    );

    expect(
      await rows(
        'SELECT sp.common_name, sp.category, s.count FROM sightings s '
        "JOIN species sp ON sp.id = s.species_id WHERE s.dive_id = 'd1' "
        'ORDER BY sp.common_name',
      ),
      [
        {'common_name': 'Aal', 'category': 'other', 'count': 1},
        {'common_name': 'Barsch', 'category': 'other', 'count': 1},
        {'common_name': 'Krebse', 'category': 'other', 'count': 1},
      ],
    );

    expect(
      await rows(
        'SELECT field_key, field_value FROM dive_custom_fields '
        "WHERE dive_id = 'd1' ORDER BY sort_order",
      ),
      [
        {'field_key': 'Suit', 'field_value': 'Drysuit'},
        {'field_key': 'Environment', 'field_value': 'See'},
        {'field_key': 'Comfort', 'field_value': 'Optimal'},
        {'field_key': 'Buoyancy', 'field_value': 'Negativ, Neutral'},
        {'field_key': 'State of mind', 'field_value': 'Entspannt'},
      ],
    );
  });

  test("uses the diver's visibility scale", () async {
    await attach(scale: VisibilityScale.coldWater);

    final good = VisibilityScale.coldWater.rangeFor(VisibilityBand.good);
    final row = await dive();
    expect(row['visibility_min_meters'], good.minM);
    expect(row['visibility_max_meters'], good.maxM);
  });

  test('leaves what the diver already logged', () async {
    await db.customStatement(
      "INSERT INTO dive_centers (id, diver_id, name, created_at, updated_at) "
      "VALUES ('c-mine', '$diverId', 'My Shop', 1000, 1000)",
    );
    await db.customStatement(
      "UPDATE dives SET dive_center_id = 'c-mine', visibility_meters = 8, "
      "current_strength = 'strong' WHERE id = 'd1'",
    );
    await db.customStatement(
      'INSERT INTO dive_custom_fields '
      '(id, dive_id, field_key, field_value, sort_order, created_at) '
      "VALUES ('f1', 'd1', 'suit', 'Wetsuit', 0, 1000)",
    );
    await db.customStatement(
      'INSERT INTO dive_weights (id, dive_id, weight_type, amount_kg, '
      "created_at) VALUES ('w1', 'd1', 'integrated', 4, 1000)",
    );
    await db.customStatement(
      'INSERT INTO species (id, common_name, category) '
      "VALUES ('sp-eel', 'aal', 'fish')",
    );
    await db.customStatement(
      'INSERT INTO sightings (id, dive_id, species_id, count) '
      "VALUES ('s1', 'd1', 'sp-eel', 3)",
    );

    await attach();

    final row = await dive();
    expect(row['dive_center_id'], 'c-mine');
    // The journal's center is not even created: it would sit unlinked in
    // the diver's list.
    expect(await count('dive_centers'), 1);
    expect(row['visibility_meters'], 8);
    expect(row['visibility_min_meters'], isNull);
    expect(row['current_strength'], 'strong');
    expect(
      await rows("SELECT amount_kg FROM dive_weights WHERE dive_id = 'd1'"),
      [
        {'amount_kg': 4.0},
      ],
    );
    expect(
      await rows(
        "SELECT field_value FROM dive_custom_fields WHERE field_key = 'suit'",
      ),
      [
        {'field_value': 'Wetsuit'},
      ],
    );
    expect(
      await rows("SELECT count FROM sightings WHERE species_id = 'sp-eel'"),
      [
        {'count': 3},
      ],
    );
    expect(
      await rows("SELECT id FROM species WHERE lower(common_name) = 'aal'"),
      hasLength(1),
    );
  });

  test('a second attach adds nothing', () async {
    await attach();
    final before = [
      for (final t in [
        'dive_centers',
        'dive_custom_fields',
        'sightings',
        'species',
        'dive_weights',
      ])
        await count(t),
    ];

    await attach();

    final after = [
      for (final t in [
        'dive_centers',
        'dive_custom_fields',
        'sightings',
        'species',
        'dive_weights',
      ])
        await count(t),
    ];
    expect(after, before);
  });

  test('one failing detail does not stop the others', () async {
    final failing = SuuntoJournalWriter(centers: _ThrowingCenters());

    await failing.attach(
      'd1',
      parsed(),
      diverId,
      scale: VisibilityScale.tropical,
    );

    final row = await dive();
    expect(row['dive_center_id'], isNull);
    expect(row['current_strength'], 'none');
    expect(row['visibility_min_meters'], isNotNull);
    expect(await count('dive_custom_fields'), 5);
    expect(await count('sightings'), 3);
    expect(await count('dive_weights'), 1);
  });

  test('one animal failing does not cost the dive the others', () async {
    final failing = SuuntoJournalWriter(species: _FailingSpecies('Barsch'));

    await failing.attach(
      'd1',
      parsed(),
      diverId,
      scale: VisibilityScale.tropical,
    );

    expect(
      await rows(
        'SELECT sp.common_name FROM sightings s '
        "JOIN species sp ON sp.id = s.species_id WHERE s.dive_id = 'd1' "
        'ORDER BY sp.common_name',
      ),
      [
        {'common_name': 'Aal'},
        {'common_name': 'Krebse'},
      ],
    );
  });

  test('an empty journal writes nothing', () async {
    await writer.attach(
      'd1',
      parsed(SuuntoJournal.empty),
      diverId,
      scale: VisibilityScale.tropical,
    );

    expect((await dive())['updated_at'], 1000);
  });
}

class _ThrowingCenters extends DiveCenterRepository {
  @override
  Future<DiveCenter> findOrCreateByName(
    String name, {
    required String diverId,
  }) async => throw StateError('disk full');
}

class _FailingSpecies extends SpeciesRepository {
  _FailingSpecies(this.failingName);

  final String failingName;

  @override
  Future<Species> getOrCreateSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
  }) async {
    if (commonName == failingName) throw StateError('disk full');
    return super.getOrCreateSpecies(
      commonName: commonName,
      scientificName: scientificName,
      category: category,
    );
  }
}
