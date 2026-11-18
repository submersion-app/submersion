import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/test_database.dart';

/// Issue #4714: the one-tap repair of a cylinder mix an older import stored
/// 100 times too high.
void main() {
  late DiveRepository diveRepo;
  late QualityFindingsRepository findingsRepo;
  late QualityRepairExecutor executor;

  setUp(() async {
    await setUpTestDatabase();
    // The executor queues a targeted rescan; keep it out of the test zone.
    QualityScanScheduler.enabled = false;
    diveRepo = DiveRepository();
    findingsRepo = QualityFindingsRepository();
    executor = QualityRepairExecutor();
  });
  tearDown(() {
    applyGlobalTestDefaults();
    return tearDownTestDatabase();
  });

  Future<void> diveWith(domain.GasMix mix) => diveRepo.createDive(
    domain.Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026, 7, 1),
      tanks: [domain.DiveTank(id: 't1', gasMix: mix)],
    ),
  );

  Future<QualityFinding> seedFinding() async {
    final finding = QualityFinding(
      id: qualityFindingId(
        diveId: 'd1',
        detectorId: 'impossible_gas_mix',
        discriminator: 'tank:t1',
      ),
      diveId: 'd1',
      detectorId: 'impossible_gas_mix',
      detectorVersion: 1,
      category: QualityCategory.gas,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    await findingsRepo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'impossible_gas_mix'},
      produced: [finding],
    );
    return finding;
  }

  Future<domain.GasMix> storedMix() async =>
      (await diveRepo.getDiveById('d1'))!.tanks.single.gasMix;

  Future<QualityStatus> status() async =>
      (await findingsRepo.getFindings(diveId: 'd1')).single.status;

  test('divides the mix and resolves the finding', () async {
    await diveWith(const domain.GasMix(o2: 2100, he: 3500));
    final finding = await seedFinding();

    final result = await executor.rescaleGasMix(
      diveId: 'd1',
      tankId: 't1',
      mix: const domain.GasMix(o2: 21, he: 35),
      findingId: finding.id,
    );

    expect(result.changed, isTrue);
    expect(await storedMix(), const domain.GasMix(o2: 21, he: 35));
    expect(await status(), QualityStatus.resolved);
    // It is what the next launch would write anyway (rescaleAll), so an
    // undo putting the impossible mix back could not last.
    expect(result.undo, isNull);
  });

  test('reports no change when the cylinder is gone', () async {
    await diveWith(const domain.GasMix(o2: 3200));
    final finding = await seedFinding();

    final result = await executor.rescaleGasMix(
      diveId: 'd1',
      tankId: 'gone',
      mix: const domain.GasMix(o2: 32),
      findingId: finding.id,
    );

    expect(result.changed, isFalse);
    expect(await status(), QualityStatus.open);
  });

  test('refuses a mix corrected by hand since the scan', () async {
    // Dividing a hand-set 32% again would store 0.32%.
    await diveWith(const domain.GasMix(o2: 32));
    final finding = await seedFinding();

    final result = await executor.rescaleGasMix(
      diveId: 'd1',
      tankId: 't1',
      mix: const domain.GasMix(o2: 32),
      findingId: finding.id,
    );

    expect(result.changed, isFalse);
    expect(await storedMix(), const domain.GasMix(o2: 32));
    expect(await status(), QualityStatus.open);
  });

  test('refuses when the stored mix no longer divides to the offer', () async {
    // Edited to another impossible value since the scan: the button named
    // EAN32, and writing EAN50 under it would not be what the diver chose.
    await diveWith(const domain.GasMix(o2: 5000));
    final finding = await seedFinding();

    final result = await executor.rescaleGasMix(
      diveId: 'd1',
      tankId: 't1',
      mix: const domain.GasMix(o2: 32),
      findingId: finding.id,
    );

    expect(result.changed, isFalse);
    expect(await storedMix(), const domain.GasMix(o2: 5000));
  });
}
