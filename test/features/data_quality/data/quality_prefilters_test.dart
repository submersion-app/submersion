import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_prefilters.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late ProfileSeriesRepository profileSeries;
  late QualityPrefilters prefilters;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    profileSeries = ProfileSeriesRepository();
    prefilters = QualityPrefilters();
  });
  tearDown(tearDownTestDatabase);

  test('shared gear candidates are dives sharing an item with another '
      "profile's dive in the window", () async {
    final db = DatabaseService.instance.database;
    final ten = DateTime.utc(2026, 5, 1, 10).millisecondsSinceEpoch;
    const hour = 3600 * 1000;
    for (final id in ['bill', 'anna']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'light',
            name: 'light',
            type: 'light',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final (id, diver, at) in [
      ('b1', 'bill', ten),
      ('a1', 'anna', ten),
      ('b2', 'bill', ten + hour),
      ('n1', null, ten),
      ('a2', 'anna', ten + 72 * hour),
    ]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diverId: Value(diver),
              diveDateTime: at,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: id, equipmentId: 'light'),
          );
    }
    final candidates = await prefilters.candidatesByDetector();
    // b2 pairs with a1 (an hour apart, inside the window); n1 has no
    // profile; a2 is three days away from every other dive.
    expect(candidates['shared_gear_overlap'], {'b1', 'a1', 'b2'});
  });

  // A detector without a candidate set never runs in a full library scan,
  // yet counts as run, so the scan retires all of its findings (#2870).
  test('every registered detector has a candidate set', () async {
    final candidates = await prefilters.candidatesByDetector();
    expect(
      candidates.keys.toSet(),
      containsAll(kQualityDetectors.map((d) => d.id)),
    );
  });

  test('unknown transmitter candidates carry a real serial', () async {
    for (final (id, serial) in [
      ('real', ' 0012 '),
      ('zeros', '000'),
      ('blank', '  '),
      ('none', null),
    ]) {
      await diveRepo.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime.utc(2026, 6, 1),
          tanks: [domain.DiveTank(id: 't-$id', transmitterSerial: serial)],
        ),
      );
    }
    final candidates = await prefilters.candidatesByDetector();
    expect(candidates['unknown_transmitter'], {'real'});
  });

  test('registry contains all 13 detectors with unique ids', () {
    final ids = kQualityDetectors.map((d) => d.id).toList();
    expect(ids.toSet(), hasLength(13));
    expect(
      ids.toSet(),
      containsAll({
        'clock_offset',
        'duplicate',
        'split_pair',
        'sample_gap',
        'depth_spike',
        'impossible_rate',
        'temp_anomaly',
        'pressure_anomaly',
        'gas_mod',
        'tank_assignment',
        'unknown_transmitter',
        'source_conflict',
        'shared_gear_overlap',
      }),
    );
    // Each bump is what raises the "new checks are available" banner, so an
    // existing library gets the new fact on a rescan rather than keeping a
    // button the fact would have withheld. v2 records `sameComputer` on every
    // duplicate pair, so a Consolidate that cannot work is not offered. v4
    // withholds `redundantDiveId` when the copy it would delete carries the
    // diver's own entries (#1720), and the repair mapping refuses to act on a
    // pre-v4 finding, so the rescan is what restores the repair.
    expect(qualityDetectorVersions()['duplicate'], 4);
  });

  test('profile detectors only get dives that have profiles', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await diveRepo.createDive(
      domain.Dive(
        id: 'with-profile',
        dateTime: entry,
        entryTime: entry,
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 60, depth: 20),
        ],
      ),
    );
    await diveRepo.createDive(
      domain.Dive(id: 'bare', dateTime: entry.add(const Duration(days: 30))),
    );
    final candidates = await prefilters.candidatesByDetector();
    expect(candidates['sample_gap'], contains('with-profile'));
    expect(candidates['sample_gap'], isNot(contains('bare')));
    expect(candidates['depth_spike'], contains('with-profile'));
  });

  test('a dive with only non-primary profile rows is not a profile '
      'candidate (matches the context builder)', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await diveRepo.createDive(domain.Dive(id: 'np-only', dateTime: entry));
    // A demoted/secondary source leaves only non-primary samples; the context
    // builder loads is_primary=1 only, so this dive has no series to detect on.
    await profileSeries.insertSeries(
      diveId: 'np-only',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 12.0)],
    );
    final candidates = await prefilters.candidatesByDetector();
    expect(candidates['sample_gap'], isNot(contains('np-only')));
    expect(candidates['depth_spike'], isNot(contains('np-only')));
    expect(candidates['impossible_rate'], isNot(contains('np-only')));
  });

  test('pair window selects both members of a close pair', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await diveRepo.createDive(
      domain.Dive(id: 'a', dateTime: entry, entryTime: entry),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'b',
        dateTime: entry.add(const Duration(minutes: 30)),
        entryTime: entry.add(const Duration(minutes: 30)),
      ),
    );
    await diveRepo.createDive(
      domain.Dive(id: 'far', dateTime: entry.add(const Duration(days: 30))),
    );
    final candidates = await prefilters.candidatesByDetector();
    expect(candidates['duplicate'], containsAll({'a', 'b'}));
    expect(candidates['duplicate'], isNot(contains('far')));
  });

  test('future-dated dive is a clock_offset candidate', () async {
    await diveRepo.createDive(
      domain.Dive(id: 'future', dateTime: DateTime.utc(2031, 1, 1)),
    );
    final candidates = await prefilters.candidatesByDetector(
      now: DateTime.utc(2026, 7, 17),
    );
    expect(candidates['clock_offset'], contains('future'));
  });
}
