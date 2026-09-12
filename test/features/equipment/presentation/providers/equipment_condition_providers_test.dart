import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
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

/// Always reports a low cell on the rebreather, whatever it is given.
class _EmitsCellFinding extends EquipmentConditionEngine {
  @override
  List<EquipmentFinding> evaluate(ConditionEngineInput input) {
    final evidence = FindingEvidence(
      n: 3,
      windowStart: DateTime.utc(2026),
      windowEnd: DateTime.utc(2026),
      slot: 1,
    );
    return [
      ...super.evaluate(input),
      EquipmentFinding(
        id: conditionFindingId(
          input.item.id,
          ConditionRuleId.cellOutputLow,
          slot: 1,
        ),
        equipmentId: input.item.id,
        ruleId: ConditionRuleId.cellOutputLow,
        severity: ConditionSeverity.significant,
        evidence: evidence,
        evidenceFingerprint: evidenceFingerprint(evidence),
        engineVersion: EquipmentConditionEngine.engineVersion,
        createdAt: DateTime.utc(2026),
      ),
    ];
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late MockSettingsNotifier settings;
  late _CountingEngine engine;
  late EquipmentObservationRepository observations;
  late IncidentRepository incidents;

  final summariesRequested = <String>{};

  Future<void> setUpWith({bool logStatements = false}) async {
    summariesRequested.clear();
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
            requestSummaries: summariesRequested.addAll,
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

  /// Polls until the engine call count stops moving; returns it.
  Future<int> untilSettled() async {
    var last = -1;
    for (var i = 0; i < 100 && last != engine.calls; i++) {
      last = engine.calls;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return engine.calls;
  }

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
            // The transmitter item it is; equipmentId would be the cylinder.
            transmitterEquipmentId: const Value('tx'),
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
    // No rule reads a regulator's summaries, so its first review is
    // complete without one and asks for none.
    final settled = await untilSettled();
    expect(summariesRequested, isEmpty);
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
    await untilCalls(settled + 1);
    expect(engine.calls, greaterThan(settled));
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

  test(
    'without its summaries a device keeps a synced sensor finding',
    () async {
      // Summaries are device-local and a synced dive arrives without one.
      // Recomputing then would find no cell readings, call the peer's
      // finding "stopped firing", and tombstone it on every device.
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
              id: 'synced',
              diveDateTime: DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
              createdAt: 1,
              updatedAt: 5,
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'synced', equipmentId: 'ccr'),
          );
      await db
          .into(db.equipmentFindings)
          .insert(
            EquipmentFindingsCompanion.insert(
              id: 'cf_ccr_cellOutputLow_1',
              equipmentId: 'ccr',
              ruleId: 'cellOutputLow',
              severity: 'significant',
              evidenceFingerprint: 'peer',
              engineVersion: 1,
              createdAt: 1,
            ),
          );
      await db.delete(db.deletionLog).go();

      await container.read(equipmentConditionProvider('ccr').future);

      final rows = await db.select(db.equipmentFindings).get();
      expect(rows.map((r) => r.id), contains('cf_ccr_cellOutputLow_1'));
      expect(await db.select(db.deletionLog).get(), isEmpty);
      // No marker either: the review was partial, so the next read with the
      // summaries in place must recompute rather than serve this one.
      expect(
        await EquipmentFindingsRepository(db: db).getReview('ccr'),
        isNull,
      );
      expect(summariesRequested, {'synced'});
    },
  );

  Future<void> ccrWithDive({required int summaryStamp}) async {
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
            id: 'loop',
            diveDateTime: DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 5,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'loop', equipmentId: 'ccr'),
        );
    await db
        .into(db.diveSensorSummaries)
        .insert(
          DiveSensorSummariesCompanion.insert(
            diveId: 'loop',
            engineVersion: 1,
            sourceUpdatedAt: summaryStamp,
            computedAt: 1,
          ),
        );
  }

  test('a stale summary never reaches the engine', () async {
    // Built from an older version of the dive: the rebuild is requested,
    // and until it lands the engine must not read the old readings.
    await ccrWithDive(summaryStamp: 3);
    await container.read(equipmentConditionProvider('ccr').future);
    expect(engine.last!.summariesByDive, isEmpty);
    expect(summariesRequested, {'loop'});
  });

  test('a current summary does reach the engine', () async {
    await ccrWithDive(summaryStamp: 5);
    await container.read(equipmentConditionProvider('ccr').future);
    expect(engine.last!.summariesByDive.keys, ['loop']);
  });

  test('a rebuilt summary recomputes the item', () async {
    // A forced rebuild keeps the source stamp (the dive did not change)
    // but can change the readings, so it must not leave the marker
    // matching.
    await ccrWithDive(summaryStamp: 5);
    await container.read(equipmentConditionProvider('ccr').future);
    final before = engine.calls;
    await (db.update(db.diveSensorSummaries)
          ..where((s) => s.diveId.equals('loop')))
        .write(const DiveSensorSummariesCompanion(computedAt: Value(2)));
    container.invalidate(equipmentConditionProvider('ccr'));
    await container.read(equipmentConditionProvider('ccr').future);
    expect(engine.calls, before + 1);
  });

  test('while summaries are missing the sensor rules write nothing', () async {
    // Partial readings cannot be trusted either way: the rules neither
    // delete a finding nor write one until every summary is current.
    await ccrWithDive(summaryStamp: 3);
    final refresher = EquipmentConditionRefresher(
      equipment: EquipmentRepository(),
      observations: observations,
      incidents: incidents,
      transmitters: TransmitterRepository(),
      summaries: DiveSensorSummaryRepository(db: db),
      findings: EquipmentFindingsRepository(db: db),
      engine: _EmitsCellFinding(),
    );
    await refresher.ensureCurrent(
      'ccr',
      thresholds: ExposureThresholds.defaults,
      engineEnabled: true,
    );
    final rows = await db.select(db.equipmentFindings).get();
    expect(rows.where((r) => r.ruleId == 'cellOutputLow'), isEmpty);
  });

  test('an item no summary rule reads is reviewed without them', () async {
    // Only cells, rebreathers and transmitters have summary rules. A
    // regulator waiting on summaries it never reads recorded no marker and
    // asked for them again on every pass.
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
    await read();
    expect(summariesRequested, isEmpty);
    expect(
      await EquipmentFindingsRepository(db: db).getReview('reg'),
      isNotNull,
    );
  });

  test('a type change drops the sensor findings the old type made', () async {
    // A rebreather's cell finding, then the item becomes a regulator with a
    // dive not yet summarised. No rule of the new type reads summaries, so
    // the old finding must not be kept waiting for them.
    await ccrWithDive(summaryStamp: 5);
    EquipmentConditionRefresher refresher(EquipmentConditionEngine engine) =>
        EquipmentConditionRefresher(
          equipment: EquipmentRepository(),
          observations: observations,
          incidents: incidents,
          transmitters: TransmitterRepository(),
          summaries: DiveSensorSummaryRepository(db: db),
          findings: EquipmentFindingsRepository(db: db),
          engine: engine,
        );
    Future<List<EquipmentFinding>> refresh(EquipmentConditionEngine e) async =>
        (await refresher(e).ensureCurrent(
          'ccr',
          thresholds: ExposureThresholds.defaults,
          engineEnabled: true,
        ))!;
    expect(
      (await refresh(_EmitsCellFinding())).map((f) => f.ruleId),
      contains(ConditionRuleId.cellOutputLow),
    );
    await (db.update(db.equipment)..where((e) => e.id.equals('ccr'))).write(
      const EquipmentCompanion(type: Value('regulator'), updatedAt: Value(9)),
    );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'unsummarised',
            diveDateTime: DateTime.utc(2026, 2, 1).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'unsummarised',
            equipmentId: 'ccr',
          ),
        );
    expect(
      (await refresh(const EquipmentConditionEngine())).map((f) => f.ruleId),
      isNot(contains(ConditionRuleId.cellOutputLow)),
    );
  });

  testWidgets('dismissing a finding stores it and refreshes the item', (
    tester,
  ) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    final finding = (await tester.runAsync(read))!.single;
    expect(finding.dismissedAt, isNull);

    await tester.runAsync(
      () => setConditionFindingDismissed(
        widgetRef,
        finding: finding,
        dismissed: true,
      ),
    );
    // Invalidated, so the next read serves the dismissal, not the cache.
    expect((await tester.runAsync(read))!.single.dismissedAt, isNotNull);

    await tester.runAsync(
      () => setConditionFindingDismissed(
        widgetRef,
        finding: finding,
        dismissed: false,
      ),
    );
    expect((await tester.runAsync(read))!.single.dismissedAt, isNull);
  });

  test('incident dives count towards clearing a dismissal', () async {
    // incidentLinked names each incident's dive, and the item may never
    // have been linked to those dives. Their dates must still be known,
    // or a dismissed incident finding could never clear.
    for (var i = 1; i <= 3; i++) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'i$i',
              diveDateTime: DateTime.utc(2026, 3, i).millisecondsSinceEpoch,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    final first = await read();
    final finding = first!.single;
    await EquipmentFindingsRepository(db: db).setDismissed(
      findingId: finding.id,
      dismissed: true,
      now: DateTime.utc(2026, 2, 1),
    );
    for (var i = 1; i <= 3; i++) {
      await incidents.createIncident(
        occurredAt: DateTime.utc(2026, 3, i),
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.moderate,
        narrative: 'n$i',
        diveId: 'i$i',
        equipmentId: 'reg',
      );
    }
    container.invalidate(equipmentConditionProvider('reg'));
    final after = await read();
    expect(after!.single.isDismissed, isFalse);
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
