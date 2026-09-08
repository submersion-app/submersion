import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_inbox_providers.dart';
import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
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

  group('qualityFindingDivesProvider', () {
    // Review asked for `.value` over the house `valueOrNull` extension, on the
    // grounds that a watchDivesChanges() invalidation drops the loaded map and
    // flashes the fallback. It does not: a self-invalidate is a REFRESH, and
    // AsyncValue.when skips the loading branch on a refresh
    // (skipLoadingOnRefresh defaults to true), so the previous map is handed
    // to the data branch instead. This pins that, because the difference is
    // invisible until someone changes the extension.
    test(
      'an invalidation keeps the loaded identities, it does not flash',
      () async {
        await diveRepo.createDive(
          domain.Dive(
            id: 'd1',
            name: 'Reef wall',
            dateTime: DateTime.utc(2026, 6, 14, 9, 12),
          ),
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final provider = qualityFindingDivesProvider('d1');
        final loaded = await container.read(provider.future);
        expect(loaded['d1']?.effectiveName, 'Reef wall');

        container.invalidate(provider);
        final refreshing = container.read(provider);

        expect(refreshing.isLoading, isTrue, reason: 'a refresh is in flight');
        expect(
          refreshing.valueOrNull?['d1']?.effectiveName,
          'Reef wall',
          reason: 'the previous identities survive the refresh',
        );
      },
    );

    test('a dive id with no row is simply absent from the map', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final map = await container.read(
        qualityFindingDivesProvider('missing').future,
      );
      expect(map, isEmpty);
    });
  });

  group('qualityComputerNamesProvider', () {
    // The page tests override this provider, so without a test here the real
    // mapping (the part that decides what "Recorded by ..." actually says)
    // would never run.
    test('maps saved computer ids to their display names', () async {
      final container = ProviderContainer(
        overrides: [
          allDiveComputersProvider.overrideWith(
            (ref) async => [
              DiveComputer(
                id: 'c1',
                name: 'Perdix AI',
                createdAt: DateTime.utc(2026, 7, 17),
                updatedAt: DateTime.utc(2026, 7, 17),
              ),
              DiveComputer(
                id: 'c2',
                name: '',
                manufacturer: 'Shearwater',
                model: 'Teric',
                createdAt: DateTime.utc(2026, 7, 17),
                updatedAt: DateTime.utc(2026, 7, 17),
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final names = await container.read(qualityComputerNamesProvider.future);
      expect(names['c1'], 'Perdix AI');
      // An unnamed computer falls back to DiveComputer.displayName rather than
      // rendering an empty label.
      expect(names['c2'], isNotEmpty);
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
