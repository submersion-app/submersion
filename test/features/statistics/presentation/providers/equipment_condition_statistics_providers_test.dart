import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/equipment_condition_statistics_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The three ranking cards on the equipment statistics page.
void main() {
  late AppDatabase db;
  late MockSettingsNotifier settings;
  late ProviderContainer container;
  late EquipmentItem reg;
  late EquipmentItem bcd;

  Future<void> dive(String id, int day, {int runtime = 3600, double? temp}) =>
      db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: DateTime.utc(2026, 1, day).millisecondsSinceEpoch,
              createdAt: 1,
              updatedAt: 1,
            ).copyWith(runtime: Value(runtime), waterTemp: Value(temp)),
          );

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );

  EquipmentFinding finding(String equipmentId, ConditionRuleId rule) {
    final evidence = FindingEvidence(
      n: 3,
      windowStart: DateTime(2026),
      windowEnd: DateTime(2026, 2),
    );
    return EquipmentFinding(
      id: conditionFindingId(equipmentId, rule),
      equipmentId: equipmentId,
      ruleId: rule,
      severity: rule.severity,
      evidence: evidence,
      evidenceFingerprint: evidenceFingerprint(evidence),
      engineVersion: 1,
      createdAt: DateTime(2026, 2),
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    settings = MockSettingsNotifier();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final repo = EquipmentRepository();
    reg = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    bcd = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'BCD', type: EquipmentType.bcd),
    );
    // Reg: three warm hours. BCD: one cold hour and one cold half hour.
    await dive('r1', 1, temp: 20);
    await dive('r2', 2, temp: 21);
    await dive('r3', 3, temp: 22);
    await dive('b1', 4, temp: 5);
    await dive('b2', 5, temp: 6, runtime: 1800);
    for (final d in ['r1', 'r2', 'r3']) {
      await link(d, reg.id);
    }
    for (final d in ['b1', 'b2']) {
      await link(d, bcd.id);
    }
  });
  tearDown(tearDownTestDatabase);

  test('exposure ranking follows the chosen unit', () async {
    final byHours = await container.read(exposureRankingProvider.future);
    expect(byHours.map((r) => r.id), [reg.id, bcd.id]);
    expect(byHours.first.count, 3);
    expect(byHours.first.value, closeTo(3.0, 1e-9));

    container.read(exposureRankingUnitProvider.notifier).state =
        ExposureUnit.coldDives;
    final byCold = await container.read(exposureRankingProvider.future);
    expect(byCold.map((r) => r.id), [bcd.id]);
    expect(byCold.single.count, 2);
  });

  test(
    'findings by rule counts open findings and hides a disabled rule',
    () async {
      final findings = EquipmentFindingsRepository(db: db);
      await findings.saveReview(
        equipmentId: reg.id,
        inputFingerprint: 'a',
        findings: [
          finding(reg.id, ConditionRuleId.issueRecurring),
          finding(reg.id, ConditionRuleId.incidentLinked),
        ],
        now: DateTime(2026, 2),
      );
      await findings.saveReview(
        equipmentId: bcd.id,
        inputFingerprint: 'b',
        findings: [finding(bcd.id, ConditionRuleId.issueRecurring)],
        now: DateTime(2026, 2),
      );
      final ranking = await container.read(findingsByRuleProvider.future);
      expect(ranking.map((r) => '${r.id}:${r.count}'), [
        'issueRecurring:2',
        'incidentLinked:1',
      ]);
      expect(ranking.first.name, 'Recurring issue');

      await settings.setConditionRuleEnabled(
        ConditionRuleId.issueRecurring,
        false,
      );
      container.invalidate(findingsByRuleProvider);
      final filtered = await container.read(findingsByRuleProvider.future);
      expect(filtered.map((r) => r.id), ['incidentLinked']);
    },
  );

  test('issue tags rank by how often they were reported', () async {
    final observations = EquipmentObservationRepository(db: db);
    await observations.create(
      equipmentId: reg.id,
      observedAt: DateTime(2026, 1, 1),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.freeFlow, ObservationTag.hardBreathing],
    );
    await observations.create(
      equipmentId: bcd.id,
      observedAt: DateTime(2026, 1, 2),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.freeFlow],
    );
    await observations.create(
      equipmentId: bcd.id,
      observedAt: DateTime(2026, 1, 3),
      status: ObservationStatus.ok,
    );
    final ranking = await container.read(issueTagRankingProvider.future);
    expect(ranking.map((r) => '${r.id}:${r.count}'), [
      'freeFlow:2',
      'hardBreathing:1',
    ]);
    expect(ranking.first.name, 'Free flow');
  });
}
