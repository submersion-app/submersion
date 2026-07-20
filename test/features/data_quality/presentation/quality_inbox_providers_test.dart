import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_inbox_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late QualityFindingsRepository findingsRepo;

  setUp(() async {
    await setUpTestDatabase();
    QualityScanScheduler.enabled = false;
    diveRepo = DiveRepository();
    findingsRepo = QualityFindingsRepository();
  });
  tearDown(() {
    QualityScanScheduler.enabled = true;
    return tearDownTestDatabase();
  });

  group('importedDivesFindingsKey', () {
    test('sorts so equal id sets in any order yield the same key', () {
      expect(
        importedDivesFindingsKey(['b', 'a', 'c']),
        importedDivesFindingsKey(['c', 'b', 'a']),
      );
      expect(importedDivesFindingsKey(['a', 'b']), 'a,b');
    });

    test('an empty id set yields the empty key', () {
      expect(importedDivesFindingsKey(const []), '');
    });
  });

  test('core providers construct their singletons', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(qualityFindingsRepositoryProvider),
      isA<QualityFindingsRepository>(),
    );
    expect(
      container.read(qualityScanServiceProvider),
      isA<QualityScanService>(),
    );
  });

  Future<QualityFinding> seedOpenFinding(
    String diveId, {
    String? related,
  }) async {
    final finding = QualityFinding(
      id: qualityFindingId(diveId: diveId, detectorId: 'clock_offset'),
      diveId: diveId,
      relatedDiveId: related,
      detectorId: 'clock_offset',
      detectorVersion: 1,
      category: QualityCategory.time,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    await findingsRepo.applyScanResults(
      scopeDiveIds: {diveId},
      ranDetectorIds: {'clock_offset'},
      produced: [finding],
    );
    return finding;
  }

  test(
    'counts open findings whose dive or related dive is in the key set',
    () async {
      for (final id in ['d1', 'd2', 'd3']) {
        await diveRepo.createDive(
          domain.Dive(id: id, dateTime: DateTime.utc(2026, 7, 1)),
        );
      }
      await seedOpenFinding('d1');
      await seedOpenFinding('d2');
      // d3's finding is outside the key set and must not be counted.
      await seedOpenFinding('d3');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final key = importedDivesFindingsKey(['d2', 'd1']);
      // Keep the autoDispose provider alive across the await so its stream
      // future resolves instead of being disposed mid-read.
      final sub = container.listen(
        importedDivesOpenFindingsCountProvider(key),
        (_, _) {},
      );
      addTearDown(sub.close);
      final count = await container.read(
        importedDivesOpenFindingsCountProvider(key).future,
      );
      expect(count, 2);
    },
  );

  test('an empty key set counts nothing', () async {
    await diveRepo.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1)),
    );
    await seedOpenFinding('d1');

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(
      importedDivesOpenFindingsCountProvider(''),
      (_, _) {},
    );
    addTearDown(sub.close);
    final count = await container.read(
      importedDivesOpenFindingsCountProvider('').future,
    );
    expect(count, 0);
  });
}
