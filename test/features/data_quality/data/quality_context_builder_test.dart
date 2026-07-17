import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/services/quality_context_builder.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late QualityContextBuilder builder;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    builder = QualityContextBuilder();
  });
  tearDown(tearDownTestDatabase);

  Future<String> seedDive({
    required String id,
    required DateTime entry,
    Duration runtime = const Duration(minutes: 40),
    String? serial,
    List<domain.DiveProfilePoint> profile = const [],
  }) async {
    final dive = domain.Dive(
      id: id,
      dateTime: entry,
      entryTime: entry,
      runtime: runtime,
      maxDepth: 30.0,
      diveComputerSerial: serial,
      profile: profile,
    );
    await diveRepo.createDive(dive);
    return id;
  }

  test('builds context with sanitized sorted samples', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await seedDive(
      id: 'd1',
      entry: entry,
      profile: [
        const domain.DiveProfilePoint(timestamp: 10, depth: 5.0),
        const domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
      ],
    );
    // Directly insert a non-finite depth row: the builder must drop it.
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion.insert(
            id: 'p-bad',
            diveId: 'd1',
            timestamp: 20,
            depth: double.infinity,
          ),
        );
    final ctx = (await builder.buildAll(['d1'])).single;
    expect(ctx.primarySamples.map((s) => s.t), [0, 10]); // sorted, bad dropped
    expect(ctx.dive.id, 'd1');
  });

  test(
    'finds same-diver neighbors within the window with edge depths',
    () async {
      final entry = DateTime.utc(2026, 7, 1, 10);
      await seedDive(id: 'dA', entry: entry, serial: 'SN-1');
      await seedDive(
        id: 'dB',
        entry: entry.add(const Duration(hours: 1)),
        serial: 'SN-1',
        profile: [
          const domain.DiveProfilePoint(timestamp: 0, depth: 4.0),
          const domain.DiveProfilePoint(timestamp: 60, depth: 1.5),
        ],
      );
      await seedDive(
        id: 'dFar',
        entry: entry.add(const Duration(days: 2)),
        serial: 'SN-1',
      );
      final ctx = (await builder.buildAll(['dA'])).single;
      expect(ctx.neighbors.map((n) => n.id), ['dB']);
      expect(ctx.neighbors.single.computerSerial, 'SN-1');
      expect(ctx.neighbors.single.firstSampleDepth, 4.0);
      expect(ctx.neighbors.single.lastSampleDepth, 1.5);
    },
  );
}
