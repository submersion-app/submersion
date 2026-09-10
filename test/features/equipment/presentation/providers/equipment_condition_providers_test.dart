import 'dart:async';

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

  @override
  List<EquipmentFinding> evaluate(ConditionEngineInput input) {
    calls++;
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
