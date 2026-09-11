import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_condition_refresher.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/services/equipment_condition_engine.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _CountingEngine extends EquipmentConditionEngine {
  int calls = 0;
  ConditionEngineInput? last;

  @override
  List<EquipmentFinding> evaluate(ConditionEngineInput input) {
    calls++;
    last = input;
    return super.evaluate(input);
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late MockSettingsNotifier settings;
  late _CountingEngine engine;
  late EquipmentObservationRepository observations;
  late IncidentRepository incidents;

  Future<void> setUpWith({bool logStatements = false}) async {
    if (DatabaseService.instance.databaseOrNull != null) {
      await tearDownTestDatabase();
    }
    db = AppDatabase(NativeDatabase.memory(logStatements: logStatements));
    DatabaseService.instance.setTestDatabase(db);
    final sync = SyncRepository(database: db);
    observations = EquipmentObservationRepository(db: db, syncRepository: sync);
    incidents = IncidentRepository();
    engine = _CountingEngine();
    settings = MockSettingsNotifier();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        equipmentConditionRefresherProvider.overrideWithValue(
          EquipmentConditionRefresher(
            equipment: EquipmentRepository(),
            observations: observations,
            incidents: incidents,
            transmitters: TransmitterRepository(),
            summaries: DiveSensorSummaryRepository(db: db),
            findings: EquipmentFindingsRepository(db: db, syncRepository: sync),
            engine: engine,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await incidents.createIncident(
      occurredAt: DateTime.utc(2026),
      category: IncidentCategory.equipment,
      severity: IncidentSeverity.moderate,
      narrative: 'n',
      equipmentId: 'reg',
    );
  }

  setUp(() => setUpWith());
  tearDown(tearDownTestDatabase);

  Future<List<EquipmentFinding>?> read() =>
      container.read(equipmentConditionProvider('reg').future);

  /// Polls until the engine has been called [times] times.
  Future<void> untilCalls(int times) async {
    for (var i = 0; i < 100 && engine.calls < times; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('a first read computes, stores and serves the findings', () async {
    final findings = await read();
    expect(findings!.map((f) => f.ruleId), [ConditionRuleId.incidentLinked]);
    expect(engine.calls, 1);
    final review = await EquipmentFindingsRepository(db: db).getReview('reg');
    expect(review, isNotNull);
  });

  test('an unknown item yields null and never computes', () async {
    expect(
      await container.read(equipmentConditionProvider('x').future),
      isNull,
    );
    expect(engine.calls, 0);
  });

  test('an unchanged item is served from the marker without writes', () async {
    await setUpWith(logStatements: true);
    await read();
    expect(engine.calls, 1);
    container.invalidate(equipmentConditionProvider('reg'));
    final logged = <String>[];
    await runZoned(
      () => read(),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    expect(engine.calls, 1);
    final touching = logged.where(
      (l) =>
          l.contains('equipment_findings') ||
          l.contains('equipment_condition_reviews'),
    );
    expect(
      touching.where((l) => l.contains('Drift: Sent')).length,
      lessThanOrEqualTo(2),
    );
    expect(
      touching.any(
        (l) =>
            l.contains('INSERT') ||
            l.contains('UPDATE') ||
            l.contains('DELETE'),
      ),
      isFalse,
    );
  });

  test('an item with no findings is served from the marker too', () async {
    // The majority of gear produces nothing. The marker has to record the
    // engine version even with an empty result, or every read recomputes.
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'clean',
            name: 'Clean',
            type: 'bcd',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final first = await container.read(
      equipmentConditionProvider('clean').future,
    );
    expect(first, isEmpty);
    expect(engine.calls, 1);

    container.invalidate(equipmentConditionProvider('clean'));
    final second = await container.read(
      equipmentConditionProvider('clean').future,
    );
    expect(second, isEmpty);
    expect(engine.calls, 1);
  });

  test('an observation write recomputes', () async {
    final sub = container.listen(equipmentConditionProvider('reg'), (_, _) {});
    addTearDown(sub.close);
    await read();
    expect(engine.calls, 1);
    await observations.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026, 2),
      status: ObservationStatus.ok,
    );
    await untilCalls(2);
    expect(engine.calls, 2);
  });

  test('an attribute write recomputes', () async {
    // A cell slot or install date lives in equipment_attributes, which a
    // write reaches without touching the equipment row.
    final sub = container.listen(equipmentConditionProvider('reg'), (_, _) {});
    addTearDown(sub.close);
    await read();
    expect(engine.calls, 1);
    await EquipmentRepository().saveAttributes('reg', [
      EquipmentAttribute.curated(
        equipmentId: 'reg',
        key: EquipmentAttrKeys.cellSlot,
        valueNum: 2,
      ),
    ]);
    await untilCalls(2);
    expect(engine.calls, 2);
  });

  test('a transmitter assignment recomputes a transmitter item', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'tx',
            name: 'Tx',
            type: 'transmitter',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final sub = container.listen(equipmentConditionProvider('tx'), (_, _) {});
    addTearDown(sub.close);
    await container.read(equipmentConditionProvider('tx').future);
    expect(engine.calls, 1);
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 't1',
            label: 'Back gas',
            tankRole: 'backGas',
            transmitterSerial: const Value('ABC123'),
            equipmentId: const Value('tx'),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await untilCalls(2);
    expect(engine.calls, 2);
  });

  test('a summary written after the first review recomputes', () async {
    // The sweep can write a dive's summary after the item was reviewed;
    // the dive does not change, so only the summary row can tell.
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'reg'),
        );
    final sub = container.listen(equipmentConditionProvider('reg'), (_, _) {});
    addTearDown(sub.close);
    await read();
    expect(engine.calls, 1);
    await db
        .into(db.diveSensorSummaries)
        .insert(
          DiveSensorSummariesCompanion.insert(
            diveId: 'd1',
            engineVersion: 1,
            sourceUpdatedAt: 1000,
            computedAt: 2000,
          ),
        );
    await untilCalls(2);
    expect(engine.calls, 2);
  });

  test('the engine sees retired cells and a creation-date cut-off', () async {
    // A retired cell tells the engine who occupied its slot, and a part
    // with no install date inherits its parent's dives only from its
    // creation, so the dive before it existed is not its evidence.
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'ccr',
            name: 'CCR',
            type: 'rebreather',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'early',
            diveDateTime: DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'early', equipmentId: 'ccr'),
        );
    for (final (id, active) in [('old', false), ('new', true)]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'o2Cell',
              createdAt: DateTime.utc(2026, 2, 1).millisecondsSinceEpoch,
              updatedAt: 1,
            ).copyWith(
              parentEquipmentId: const Value('ccr'),
              isActive: Value(active),
            ),
          );
    }
    await container.read(equipmentConditionProvider('ccr').future);
    expect(engine.last!.children.map((c) => c.id).toSet(), {'old', 'new'});

    await container.read(equipmentConditionProvider('new').future);
    expect(engine.last!.samples, isEmpty);
  });

  test('a threshold change recomputes', () async {
    final sub = container.listen(equipmentConditionProvider('reg'), (_, _) {});
    addTearDown(sub.close);
    await read();
    expect(engine.calls, 1);
    await settings.setColdWaterThresholdC(6);
    await untilCalls(2);
    expect(engine.calls, 2);
  });

  test(
    'with the engine off the stored findings are served, nothing runs',
    () async {
      await read();
      expect(engine.calls, 1);
      await settings.setConditionEngineEnabled(false);
      await observations.create(
        equipmentId: 'reg',
        observedAt: DateTime.utc(2026, 2),
        status: ObservationStatus.ok,
      );
      container.invalidate(equipmentConditionProvider('reg'));
      final findings = await read();
      expect(findings!.map((f) => f.ruleId), [ConditionRuleId.incidentLinked]);
      expect(engine.calls, 1);
    },
  );
}
