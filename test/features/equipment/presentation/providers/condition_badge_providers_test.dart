import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_badge_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/counting_findings_repository.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// One read for every list tile: the worst undismissed caution or
/// significant finding per item, after the display-time filters.
void main() {
  late AppDatabase db;
  late MockSettingsNotifier settings;
  late ProviderContainer container;

  EquipmentFinding finding(
    String equipmentId,
    ConditionRuleId rule, {
    int? slot,
  }) {
    final evidence = FindingEvidence(
      n: 3,
      windowStart: DateTime(2026, 1, 1),
      windowEnd: DateTime(2026, 2, 1),
      diveIds: const ['d1', 'd2', 'd3'],
      slot: slot,
    );
    return EquipmentFinding(
      id: conditionFindingId(equipmentId, rule, slot: slot),
      equipmentId: equipmentId,
      ruleId: rule,
      severity: rule.severity,
      value: 1,
      evidence: evidence,
      evidenceFingerprint: evidenceFingerprint(evidence),
      engineVersion: 1,
      createdAt: DateTime(2026, 2, 1),
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    settings = MockSettingsNotifier();
    container = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => settings)],
    );
    addTearDown(container.dispose);
    for (final id in ['reg', 'bcd', 'mask', 'fins']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    final repo = EquipmentFindingsRepository(db: db);
    final now = DateTime(2026, 2, 1);
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'a',
      findings: [
        finding('reg', ConditionRuleId.incidentLinked),
        finding('reg', ConditionRuleId.issueRecurring),
      ],
      engineVersion: 1,
      now: now,
    );
    await repo.saveReview(
      equipmentId: 'bcd',
      inputFingerprint: 'b',
      findings: [finding('bcd', ConditionRuleId.cellOutputLow, slot: 1)],
      engineVersion: 1,
      now: now,
    );
    await repo.saveReview(
      equipmentId: 'mask',
      inputFingerprint: 'c',
      findings: [finding('mask', ConditionRuleId.cellOutputLow, slot: 1)],
      engineVersion: 1,
      now: now,
    );
    await repo.saveReview(
      equipmentId: 'fins',
      inputFingerprint: 'd',
      findings: [finding('fins', ConditionRuleId.incidentLinked)],
      engineVersion: 1,
      now: now,
    );
    await repo.setDismissed(
      findingId: conditionFindingId(
        'mask',
        ConditionRuleId.cellOutputLow,
        slot: 1,
      ),
      dismissed: true,
      now: now,
    );
  });
  tearDown(tearDownTestDatabase);

  Future<Map<String, ConditionBadge>> read() =>
      container.read(conditionBadgeProvider.future);

  test('keeps the worst caution or significant finding per item', () async {
    final badges = await read();
    expect(badges['reg']?.severity, ConditionSeverity.caution);
    expect(badges['reg']?.rule, ConditionRuleId.issueRecurring);
    expect(badges['bcd']?.severity, ConditionSeverity.significant);
    expect(badges.containsKey('mask'), isFalse);
    // Info never badges, even alone.
    expect(badges.containsKey('fins'), isFalse);
  });

  test('a disabled rule drops out', () async {
    await settings.setConditionRuleEnabled(
      ConditionRuleId.cellOutputLow,
      false,
    );
    container.invalidate(conditionBadgeProvider);
    final badges = await read();
    expect(badges.containsKey('bcd'), isFalse);
    expect(badges['reg'], isNotNull);
  });

  test('the engine off empties the map', () async {
    await settings.setConditionEngineEnabled(false);
    container.invalidate(conditionBadgeProvider);
    expect(await read(), isEmpty);
  });

  test('the earlier rule wins between two equal severities', () async {
    // Stored later-rule first, so keeping the first row seen is not enough.
    await EquipmentFindingsRepository(db: db).saveReview(
      equipmentId: 'fins',
      inputFingerprint: 'd2',
      findings: [
        finding('fins', ConditionRuleId.issueRecurring),
        finding('fins', ConditionRuleId.cellOutputDeclining),
      ],
      engineVersion: 1,
      now: DateTime(2026, 2, 1),
    );
    expect((await read())['fins']?.rule, ConditionRuleId.cellOutputDeclining);
  });

  test('a disabled rule hands the badge to the next worst', () async {
    await EquipmentFindingsRepository(db: db).saveReview(
      equipmentId: 'bcd',
      inputFingerprint: 'b2',
      findings: [
        finding('bcd', ConditionRuleId.cellOutputLow, slot: 1),
        finding('bcd', ConditionRuleId.issueRecurring),
      ],
      engineVersion: 1,
      now: DateTime(2026, 2, 1),
    );
    expect((await read())['bcd']?.severity, ConditionSeverity.significant);

    await settings.setConditionRuleEnabled(
      ConditionRuleId.cellOutputLow,
      false,
    );
    container.invalidate(conditionBadgeProvider);
    final badge = (await read())['bcd'];
    expect(badge?.severity, ConditionSeverity.caution);
    expect(badge?.rule, ConditionRuleId.issueRecurring);
  });

  group('on a stored change', () {
    late CountingFindingsRepository findings;
    late ProviderContainer watching;
    final now = DateTime(2026, 2, 1);

    setUp(() async {
      findings = CountingFindingsRepository(db: db);
      watching = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => settings),
          equipmentFindingsRepositoryProvider.overrideWithValue(findings),
        ],
      );
      addTearDown(watching.dispose);
      // A listener keeps it active, as a list tile does: an unwatched
      // provider would only rebuild on the next read.
      final sub = watching.listen(conditionBadgeProvider, (_, _) {});
      addTearDown(sub.close);
      await watching.read(conditionBadgeProvider.future);
      expect(findings.reads, 1);
    });

    Future<Map<String, ConditionBadge>> settled() async {
      await pumpEventQueue();
      return watching.read(conditionBadgeProvider.future);
    }

    test('a marker-only review reloads nothing', () async {
      for (final fingerprint in ['a2', 'a3', 'a4']) {
        await findings.saveReview(
          equipmentId: 'reg',
          inputFingerprint: fingerprint,
          findings: [
            finding('reg', ConditionRuleId.incidentLinked),
            finding('reg', ConditionRuleId.issueRecurring),
          ],
          engineVersion: 1,
          now: now,
        );
      }
      expect((await findings.getReview('reg'))?.inputFingerprint, 'a4');
      await settled();
      expect(findings.reads, 1);
    });

    test('a new finding reaches the badge', () async {
      await findings.saveReview(
        equipmentId: 'fins',
        inputFingerprint: 'd2',
        findings: [
          finding('fins', ConditionRuleId.incidentLinked),
          finding('fins', ConditionRuleId.issueRecurring),
        ],
        engineVersion: 1,
        now: now,
      );
      expect((await settled())['fins']?.severity, ConditionSeverity.caution);
      expect(findings.reads, greaterThan(1));
    });

    test('a dismissal clears the badge', () async {
      await findings.setDismissed(
        findingId: conditionFindingId(
          'bcd',
          ConditionRuleId.cellOutputLow,
          slot: 1,
        ),
        dismissed: true,
        now: now,
      );
      expect((await settled()).containsKey('bcd'), isFalse);
    });

    test('a finding that stops firing clears the badge', () async {
      await findings.saveReview(
        equipmentId: 'bcd',
        inputFingerprint: 'b2',
        findings: const [],
        engineVersion: 1,
        now: now,
      );
      expect((await settled()).containsKey('bcd'), isFalse);
    });
  });

  test('the pick order is overdue, significant, due soon, caution', () {
    expect(pickBadgeSource(clockSeverity: null, finding: null), isNull);
    expect(
      pickBadgeSource(
        clockSeverity: null,
        finding: (
          severity: ConditionSeverity.caution,
          rule: ConditionRuleId.issueRecurring,
        ),
      ),
      BadgeSource.finding,
    );
    expect(
      pickBadgeSource(
        clockSeverity: ServiceClockSeverity.dueSoon,
        finding: (
          severity: ConditionSeverity.significant,
          rule: ConditionRuleId.cellOutputLow,
        ),
      ),
      BadgeSource.finding,
    );
    expect(
      pickBadgeSource(
        clockSeverity: ServiceClockSeverity.dueSoon,
        finding: (
          severity: ConditionSeverity.caution,
          rule: ConditionRuleId.issueRecurring,
        ),
      ),
      BadgeSource.clock,
    );
    expect(
      pickBadgeSource(
        clockSeverity: ServiceClockSeverity.overdue,
        finding: (
          severity: ConditionSeverity.significant,
          rule: ConditionRuleId.cellOutputLow,
        ),
      ),
      BadgeSource.clock,
    );
    expect(
      pickBadgeSource(clockSeverity: ServiceClockSeverity.ok, finding: null),
      isNull,
    );
  });
}
