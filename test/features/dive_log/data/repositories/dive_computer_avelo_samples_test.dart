import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/dive_parser.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4664: a downloaded Avelo dive keeps its buoyancy, gas remaining and
/// computer RMV from the downloaded sample through to the stored profile.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<String> insertComputer() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('computer-1'),
            name: const Value('Shearwater Perdix 2'),
            manufacturer: const Value('Shearwater'),
            model: const Value('Perdix 2'),
            serialNumber: const Value('SN-4664'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return 'computer-1';
  }

  DownloadedDive dive() => DownloadedDive(
    startTime: DateTime.utc(2025, 4, 19, 11, 18),
    durationSeconds: 60,
    maxDepth: 4.0,
    profile: const [
      ProfileSample(
        timeSeconds: 0,
        depth: 3.0,
        aveloBuoyancy: -0.393,
        aveloGasRemaining: 100,
        computerRmv: 10.68,
      ),
      ProfileSample(timeSeconds: 60, depth: 4.0),
    ],
  );

  test('parseProfile carries the Avelo fields', () {
    final points = const DiveParser().parseProfile(dive());
    expect(points[0].aveloBuoyancy, -0.393);
    expect(points[0].aveloGasRemaining, 100);
    expect(points[0].computerRmv, 10.68);
    expect(points[1].aveloBuoyancy, isNull);
  });

  test('an imported profile stores the Avelo fields', () async {
    final points = const DiveParser().parseProfile(dive());
    final diveId = await DiveComputerRepository().importProfile(
      computerId: await insertComputer(),
      profileStartTime: DateTime(2025, 4, 19, 11, 18),
      points: points,
      durationSeconds: 60,
    );

    final merged = await DiveRepository().getMergedProfile(diveId);
    expect(merged[0].aveloBuoyancy, -0.393);
    expect(merged[0].aveloGasRemaining, 100);
    expect(merged[0].computerRmv, 10.68);
    expect(merged[1].aveloGasRemaining, isNull);
    expect(merged[1].computerRmv, isNull);
  });
}
