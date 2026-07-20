import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/services/quality_prefilters.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late QualityPrefilters prefilters;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    prefilters = QualityPrefilters();
  });
  tearDown(tearDownTestDatabase);

  test('registry contains all 11 detectors with unique ids', () {
    final ids = kQualityDetectors.map((d) => d.id).toList();
    expect(ids.toSet(), hasLength(11));
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
        'source_conflict',
      }),
    );
    expect(qualityDetectorVersions()['duplicate'], 1);
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
    await db.customStatement(
      'INSERT INTO dive_profiles (id, dive_id, timestamp, depth, is_primary) '
      "VALUES ('np-1', 'np-only', 0, 12.0, 0)",
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
