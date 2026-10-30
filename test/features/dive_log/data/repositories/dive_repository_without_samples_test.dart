import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart'
    hide DiveCustomField, DiveWeight, Tag;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as tags;

import '../../../../helpers/drift_statement_log.dart';
import '../../../../helpers/test_database.dart';

/// Issue #3831: trip screens list dives, so they read them without decoding
/// a profile or pressure series for each one, and without one set of queries
/// per dive. The values have to come out the same as [getDivesByIds] anyway:
/// the Overview's cards are configurable and can show SAC, pressures and
/// weight from the very `Dive` this read returns.
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  final entry = DateTime.utc(2026, 3, 1, 9);
  const now = 1700000000000;

  List<domain.DiveProfilePoint> samples({double? temperature}) => [
    domain.DiveProfilePoint(timestamp: 0, depth: 0, temperature: temperature),
    domain.DiveProfilePoint(
      timestamp: 1500,
      depth: 18,
      temperature: temperature,
    ),
    domain.DiveProfilePoint(
      timestamp: 3000,
      depth: 0,
      temperature: temperature,
    ),
  ];

  /// A dive whose own row answers everything a screen shows.
  domain.Dive storedDive(String id, {DateTime? at, int? number}) {
    final start = at ?? entry;
    return domain.Dive(
      id: id,
      diveNumber: number,
      dateTime: start,
      entryTime: start,
      exitTime: start.add(const Duration(minutes: 50)),
      runtime: const Duration(minutes: 50),
      bottomTime: const Duration(minutes: 42),
      maxDepth: 18,
      avgDepth: 11,
      waterTemp: 26,
      profile: samples(temperature: 26),
      tanks: [
        domain.DiveTank(
          id: '$id-tank',
          volume: 11.1,
          startPressure: 200,
          endPressure: 60,
          gasMix: const domain.GasMix(),
        ),
      ],
    );
  }

  /// A dive that leaves [column]s of its row empty after being written.
  Future<void> clearColumns(String id, List<String> columns) =>
      db.customStatement(
        'UPDATE dives SET ${columns.map((c) => '$c = NULL').join(', ')} '
        'WHERE id = ?',
        [id],
      );

  Future<List<domain.Dive>> withBuddiesFull(List<String> ids) async =>
      BuddyRepository().withBuddies(await repository.getDivesByIds(ids));

  /// Every relation the two read paths load, each with a row in it, so
  /// parity cannot pass with both sides empty.
  Future<void> createFullyRelatedDive() async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver-1',
            name: 'D',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Salt Pier',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'center-1',
            name: 'Reef Divers',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'trip-1',
            name: 'Bonaire',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'tag-1',
            name: 'Night',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            id: 'course-1',
            diverId: 'diver-1',
            name: 'Nitrox',
            agency: 'PADI',
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await repository.createDive(
      storedDive('full').copyWith(
        diverId: 'diver-1',
        weights: const [
          DiveWeight(
            id: 'weight-1',
            diveId: 'full',
            weightType: WeightType.integrated,
            amountKg: 2,
          ),
          DiveWeight(
            id: 'weight-2',
            diveId: 'full',
            weightType: WeightType.belt,
            amountKg: 4,
          ),
        ],
        customFields: const [
          DiveCustomField(id: 'field-1', key: 'camera', value: 'GoPro'),
        ],
        tags: [
          tags.Tag(
            id: 'tag-1',
            name: 'Night',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ],
        diveTypeIds: const ['shore', 'recreational'],
        courseIds: const ['course-1'],
      ),
    );
    await db.customStatement(
      'UPDATE dives SET site_id = ?, dive_center_id = ?, trip_id = ? '
      'WHERE id = ?',
      ['site-1', 'center-1', 'trip-1', 'full'],
    );

    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'gear-1',
            diverId: const Value('diver-1'),
            name: 'Regulator',
            type: 'regulator',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion.insert(
            id: 'attr-1',
            equipmentId: 'gear-1',
            attrKey: 'colour',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'full', equipmentId: 'gear-1'),
        );

    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'buddy-1',
            name: 'Sam',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'link-1',
            diveId: 'full',
            buddyId: 'buddy-1',
            role: const Value('buddy'),
            createdAt: now,
          ),
        );
  }

  group('with the database under the app', () {
    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiveRepository();
    });
    tearDown(tearDownTestDatabase);

    test(
      'answers like getDivesByIds with buddies, minus the samples',
      () async {
        await createFullyRelatedDive();

        final lean = (await repository.getDivesByIdsWithoutSamples([
          'full',
        ])).single;
        final full = (await withBuddiesFull(['full'])).single;

        // Fixture guard: equality below means nothing over empty relations.
        expect(full.profile, isNotEmpty);
        expect(full.weights, hasLength(2));
        expect(full.customFields, isNotEmpty);
        expect(full.tags, isNotEmpty);
        expect(full.gear, isNotEmpty);
        expect(full.buddies, isNotEmpty);
        expect(full.courseIds, isNotEmpty);
        expect(full.diveTypeIds, hasLength(2));
        expect(full.site, isNotNull);
        expect(full.diveCenter, isNotNull);
        expect(full.trip, isNotNull);

        expect(lean.profile, isEmpty);
        expect(
          lean.copyWith(profile: const []),
          full.copyWith(profile: const []),
        );
      },
    );

    test('reads nothing for no ids', () async {
      expect(await repository.getDivesByIdsWithoutSamples(const []), isEmpty);
    });

    test('skips an id with no dive, and reads a repeated id once', () async {
      await repository.createDive(storedDive('a'));

      final dives = await repository.getDivesByIdsWithoutSamples([
        'a',
        'missing',
        'a',
      ]);

      expect(dives.map((d) => d.id), ['a']);
    });

    test('orders dives newest first, as getDivesByIds does', () async {
      await repository.createDive(storedDive('old', number: 1));
      await repository.createDive(
        storedDive('new', at: entry.add(const Duration(hours: 3)), number: 3),
      );
      await repository.createDive(
        storedDive('mid', at: entry.add(const Duration(hours: 1)), number: 2),
      );
      const ids = ['old', 'new', 'mid'];

      final lean = await repository.getDivesByIdsWithoutSamples(ids);

      expect(lean.map((d) => d.id), ['new', 'mid', 'old']);
      expect(
        lean.map((d) => d.id),
        (await repository.getDivesByIds(ids)).map((d) => d.id),
      );
    });

    test('keeps the order and every dive across chunks, including one that '
        'needs its samples', () async {
      for (var i = 0; i < 5; i++) {
        await repository.createDive(
          storedDive('d$i', at: entry.add(Duration(hours: i))),
        );
      }
      await clearColumns('d2', ['water_temp']);

      final dives = await repository.getDivesByIdsWithoutSamples([
        'd0',
        'd1',
        'd2',
        'd3',
        'd4',
      ], chunkSize: 2);

      expect(dives.map((d) => d.id), ['d4', 'd3', 'd2', 'd1', 'd0']);
    });

    group('a value only the samples can answer', () {
      test('water temperature comes from the profile', () async {
        await repository.createDive(
          storedDive('warm').copyWith(profile: samples(temperature: 24)),
        );
        await clearColumns('warm', ['water_temp']);

        final lean = (await repository.getDivesByIdsWithoutSamples([
          'warm',
        ])).single;

        expect(lean.waterTemp, 24);
      });

      test('runtime comes from the profile span', () async {
        await repository.createDive(storedDive('bare'));
        await clearColumns('bare', ['runtime', 'bottom_time', 'exit_time']);

        final lean = (await repository.getDivesByIdsWithoutSamples([
          'bare',
        ])).single;

        expect(lean.effectiveRuntime, const Duration(seconds: 3000));
      });

      test('a runtime with no usable exit time also counts as missing, since '
          'effectiveRuntime skips a non-positive span', () async {
        await repository.createDive(storedDive('backwards'));
        await clearColumns('backwards', ['runtime', 'bottom_time']);
        await db.customStatement(
          'UPDATE dives SET exit_time = entry_time WHERE id = ?',
          ['backwards'],
        );

        final lean = (await repository.getDivesByIdsWithoutSamples([
          'backwards',
        ])).single;

        expect(lean.effectiveRuntime, const Duration(seconds: 3000));
      });

      test('tank pressures come from the pressure series, and SAC with '
          'them', () async {
        await repository.createDive(storedDive('transmitter'));
        await db.customStatement(
          'UPDATE dive_tanks SET start_pressure = NULL, end_pressure = NULL '
          'WHERE dive_id = ?',
          ['transmitter'],
        );
        await TankPressureRepository().insertTankPressures('transmitter', {
          'transmitter-tank': [
            (timestamp: 0, pressure: 210),
            (timestamp: 1500, pressure: 130),
            (timestamp: 3000, pressure: 50),
          ],
        });

        final lean = (await repository.getDivesByIdsWithoutSamples([
          'transmitter',
        ])).single;
        final full = (await repository.getDivesByIds(['transmitter'])).single;

        expect(lean.tanks.single.startPressure, 210);
        expect(lean.tanks.single.endPressure, 50);
        expect(lean.sac, isNotNull);
        expect(lean.sac, full.sac);
      });

      test('a dive routed for its samples still carries its buddies', () async {
        await createFullyRelatedDive();
        await clearColumns('full', ['water_temp']);

        final lean = (await repository.getDivesByIdsWithoutSamples([
          'full',
        ])).single;
        final full = (await withBuddiesFull(['full'])).single;

        expect(lean.buddies, isNotEmpty);
        expect(lean, full);
      });

      test('a gap with no series behind it stays empty', () async {
        await repository.createDive(
          domain.Dive(id: 'manual', dateTime: entry, entryTime: entry),
        );

        final lean = (await repository.getDivesByIdsWithoutSamples([
          'manual',
        ])).single;

        expect(lean.waterTemp, isNull);
        expect(lean.effectiveRuntime, isNull);
      });
    });
  });

  group('what it costs', () {
    setUp(() async {
      db = AppDatabase(
        NativeDatabase.memory(
          logStatements: true,
          setup: registerAppSqlFunctions,
        ),
      );
      DatabaseService.instance.setTestDatabase(db);
      repository = DiveRepository();
    });
    tearDown(tearDownTestDatabase);

    /// Fixtures stay outside the zone: their writes would be counted too.
    Future<List<String>> createDives(int count) async {
      final ids = [for (var i = 0; i < count; i++) 'dive-$i'];
      for (final (i, id) in ids.indexed) {
        await repository.createDive(
          storedDive(id, at: entry.add(Duration(hours: i))),
        );
      }
      return ids;
    }

    test('decodes no series for dives whose rows answer everything', () async {
      final ids = await createDives(3);

      final lean = await statementsOf(
        () => repository.getDivesByIdsWithoutSamples(ids),
      );
      final full = await statementsOf(() => repository.getDivesByIds(ids));

      expect(lean.where(readsSeriesBlob), isEmpty);
      // The matcher still recognises the read it is there to forbid.
      expect(full.where(readsSeriesBlob), isNotEmpty);
    });

    test('costs the same statements for 12 dives as for 1', () async {
      final ids = await createDives(12);

      final one = await statementsOf(
        () => repository.getDivesByIdsWithoutSamples(ids.take(1).toList()),
      );
      final twelve = await statementsOf(
        () => repository.getDivesByIdsWithoutSamples(ids),
      );

      expect(twelve.length, one.length);
    });

    test('a hand-logged dive with a gap costs no more than any other: no '
        'series could fill it, so it is not routed for one', () async {
      final ids = [for (var i = 0; i < 6; i++) 'manual-$i'];
      for (final id in ids) {
        await repository.createDive(
          domain.Dive(id: id, dateTime: entry, entryTime: entry),
        );
      }

      final one = await statementsOf(
        () => repository.getDivesByIdsWithoutSamples(ids.take(1).toList()),
      );
      final six = await statementsOf(
        () => repository.getDivesByIdsWithoutSamples(ids),
      );

      expect(six.length, one.length);
    });

    test('decodes samples only for the dive that needs them', () async {
      final ids = await createDives(4);
      await clearColumns(ids[2], ['water_temp']);

      final mixed = await statementsOf(
        () => repository.getDivesByIdsWithoutSamples(ids),
      );
      final alone = await statementsOf(
        () => repository.getDivesByIds([ids[2]]),
      );

      expect(
        mixed.where(readsSeriesBlob).length,
        alone.where(readsSeriesBlob).length,
      );
    });
  });
}
