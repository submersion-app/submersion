import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/database/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';

import '../../../../helpers/test_database.dart';

class _CountingSummaries extends DiveSensorSummaryRepository {
  int reads = 0;

  @override
  Future<Map<String, DiveSensorSummary>> getSummaries(
    List<String> diveIds,
  ) async {
    reads++;
    return const {};
  }
}

class _FixedSummaries extends DiveSensorSummaryRepository {
  final Map<String, DiveSensorSummary> rows;

  _FixedSummaries(this.rows);

  @override
  Future<Map<String, DiveSensorSummary>> getSummaries(
    List<String> diveIds,
  ) async => {for (final id in diveIds) id: ?rows[id]};
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  /// Reads the item's default trend, counting the summary and check-in
  /// reads it makes.
  Future<({int summaries, int observations})> readsFor(
    EquipmentType type,
  ) async {
    final summaries = _CountingSummaries();
    var observationReads = 0;
    final container = ProviderContainer(
      overrides: [
        diveSensorSummaryRepositoryProvider.overrideWithValue(summaries),
        observationsForEquipmentProvider('x').overrideWith((ref) async {
          observationReads++;
          return const <EquipmentObservation>[];
        }),
        equipmentExposureInputsProvider('x').overrideWith(
          (ref) async => (
            item: EquipmentItem(id: 'x', name: 'X', type: type),
            parent: null,
            children: const <EquipmentItem>[],
            samples: [
              EquipmentExposureSample(
                diveId: 'd1',
                date: DateTime.utc(2026),
                durationSeconds: 3000,
                minTemperature: 8,
              ),
            ],
            classifier: const ExposureClassifier(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(
      conditionTrendProvider((equipmentId: 'x', kind: null)).future,
    );
    return (summaries: summaries.reads, observations: observationReads);
  }

  test('a temperature chart reads check-ins but no sensor summaries', () async {
    final reads = await readsFor(EquipmentType.regulator);
    expect(reads.summaries, 0);
    expect(reads.observations, 1);
  });

  test('a cell chart reads sensor summaries but no check-ins', () async {
    final reads = await readsFor(EquipmentType.rebreather);
    expect(reads.summaries, 1);
    expect(reads.observations, 0);
  });

  test('a scrubber chart still gets its series', () async {
    // Guards the kind switch: the explicit kind, not the default, decides.
    final container = ProviderContainer(
      overrides: [
        diveSensorSummaryRepositoryProvider.overrideWithValue(
          _CountingSummaries(),
        ),
        equipmentExposureInputsProvider('x').overrideWith(
          (ref) async => (
            item: const EquipmentItem(
              id: 'x',
              name: 'X',
              type: EquipmentType.rebreather,
            ),
            parent: null,
            children: const <EquipmentItem>[],
            samples: const <EquipmentExposureSample>[],
            classifier: const ExposureClassifier(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final trend = await container.read(
      conditionTrendProvider((
        equipmentId: 'x',
        kind: ConditionTrendKind.scrubberMinutes,
      )).future,
    );
    expect(trend?.kind, ConditionTrendKind.scrubberMinutes);
  });

  test('a stale summary is not plotted', () async {
    // A dive edited after its summary was built (or a summary from an
    // older engine) describes a dive that no longer exists; the engine
    // drops it until the rebuild lands, and the chart must too.
    DiveSensorSummary summary(
      String diveId, {
      required int sourceUpdatedAt,
      int engineVersion = DiveSensorSummaryService.version,
    }) => DiveSensorSummary(
      diveId: diveId,
      engineVersion: engineVersion,
      sourceUpdatedAt: sourceUpdatedAt,
      computedAt: DateTime.utc(2026),
      scrubberConsumedMinutes: 40,
    );
    EquipmentExposureSample sample(String diveId, int day) =>
        EquipmentExposureSample(
          diveId: diveId,
          date: DateTime.utc(2026, 1, day),
          durationSeconds: 3000,
          diveMode: DiveMode.ccr,
          updatedAt: 7,
        );
    final container = ProviderContainer(
      overrides: [
        diveSensorSummaryRepositoryProvider.overrideWithValue(
          _FixedSummaries({
            'current': summary('current', sourceUpdatedAt: 7),
            'edited': summary('edited', sourceUpdatedAt: 6),
            'old-engine': summary(
              'old-engine',
              sourceUpdatedAt: 7,
              engineVersion: DiveSensorSummaryService.version - 1,
            ),
          }),
        ),
        equipmentExposureInputsProvider('x').overrideWith(
          (ref) async => (
            item: const EquipmentItem(
              id: 'x',
              name: 'X',
              type: EquipmentType.rebreather,
            ),
            parent: null,
            children: const <EquipmentItem>[],
            samples: [
              sample('current', 1),
              sample('edited', 2),
              sample('old-engine', 3),
            ],
            classifier: const ExposureClassifier(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final trend = await container.read(
      conditionTrendProvider((
        equipmentId: 'x',
        kind: ConditionTrendKind.scrubberMinutes,
      )).future,
    );
    expect(trend!.series.single.points.map((p) => p.diveId), ['current']);
  });

  test('a registry edit redraws an open transmitter chart', () async {
    // The serials decide which gaps belong to the item; assigning one
    // writes only the transmitter registry.
    final summaries = _CountingSummaries();
    final container = ProviderContainer(
      overrides: [
        diveSensorSummaryRepositoryProvider.overrideWithValue(summaries),
        equipmentExposureInputsProvider('x').overrideWith(
          (ref) async => (
            item: const EquipmentItem(
              id: 'x',
              name: 'X',
              type: EquipmentType.transmitter,
            ),
            parent: null,
            children: const <EquipmentItem>[],
            samples: const <EquipmentExposureSample>[],
            classifier: const ExposureClassifier(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    const key = (equipmentId: 'x', kind: null);
    final sub = container.listen(conditionTrendProvider(key), (_, _) {});
    addTearDown(sub.close);
    await container.read(conditionTrendProvider(key).future);
    final before = summaries.reads;
    final db = DatabaseService.instance.database;
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 't1',
            label: 'Back gas',
            tankRole: 'backGas',
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(transmitterSerial: const Value('ABC123')),
        );
    for (var i = 0; i < 50 && summaries.reads == before; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(summaries.reads, greaterThan(before));
  });

  test('a registry edit leaves a cell chart alone', () async {
    // Only the transmitter chart reads the serials; any other chart
    // rebuilding on a registry write re-reads its summaries for nothing.
    final summaries = _CountingSummaries();
    final container = ProviderContainer(
      overrides: [
        diveSensorSummaryRepositoryProvider.overrideWithValue(summaries),
        equipmentExposureInputsProvider('x').overrideWith(
          (ref) async => (
            item: const EquipmentItem(
              id: 'x',
              name: 'X',
              type: EquipmentType.rebreather,
            ),
            parent: null,
            children: const <EquipmentItem>[],
            samples: const <EquipmentExposureSample>[],
            classifier: const ExposureClassifier(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    const key = (equipmentId: 'x', kind: null);
    final sub = container.listen(conditionTrendProvider(key), (_, _) {});
    addTearDown(sub.close);
    await container.read(conditionTrendProvider(key).future);
    final before = summaries.reads;
    final db = DatabaseService.instance.database;
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 't1',
            label: 'Back gas',
            tankRole: 'backGas',
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(transmitterSerial: const Value('ABC123')),
        );
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(summaries.reads, before);
  });
}
