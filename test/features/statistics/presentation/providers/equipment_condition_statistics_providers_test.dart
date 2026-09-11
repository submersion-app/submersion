import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
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
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/presentation/providers/equipment_condition_statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The three ranking cards on the equipment statistics page.
void main() {
  const en = Locale('en');
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
    final byHours = await container.read(exposureRankingProvider(en).future);
    expect(byHours.map((r) => r.id), [reg.id, bcd.id]);
    expect(byHours.first.count, 3);
    expect(byHours.first.value, closeTo(3.0, 1e-9));
    // The n behind the total: three hours across how many dives.
    expect(byHours.first.subtitle, '3 dives');
    expect(byHours.last.subtitle, '2 dives');

    container.read(exposureRankingUnitProvider.notifier).state =
        ExposureUnit.coldDives;
    final byCold = await container.read(exposureRankingProvider(en).future);
    expect(byCold.map((r) => r.id), [bcd.id]);
    expect(byCold.single.count, 2);
  });

  test('an item whose total rounds to zero is left out', () async {
    // Filtering on the raw total while displaying the rounded one put an
    // item in the list reading "0 hours" with an empty bar, and the bar
    // scales off the same count, so it also skewed every other row.
    final trace = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Torch', type: EquipmentType.light),
    );
    // 100 seconds on the loop is 0.03 hours: real, but not a whole hour.
    await dive('brief', 6, runtime: 100, temp: 22);
    await link('brief', trace.id);

    final byHours = await container.read(exposureRankingProvider(en).future);
    expect(byHours.map((r) => r.id), isNot(contains(trace.id)));
    expect(byHours.every((r) => r.count > 0), isTrue);
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
        engineVersion: 1,
        now: DateTime(2026, 2),
      );
      await findings.saveReview(
        equipmentId: bcd.id,
        inputFingerprint: 'b',
        findings: [finding(bcd.id, ConditionRuleId.issueRecurring)],
        engineVersion: 1,
        now: DateTime(2026, 2),
      );
      final ranking = await container.read(findingsByRuleProvider(en).future);
      expect(ranking.map((r) => '${r.id}:${r.count}'), [
        'issueRecurring:2',
        'incidentLinked:1',
      ]);
      expect(ranking.first.name, 'Recurring issue');

      await settings.setConditionRuleEnabled(
        ConditionRuleId.issueRecurring,
        false,
      );
      container.invalidate(findingsByRuleProvider(en));
      final filtered = await container.read(findingsByRuleProvider(en).future);
      expect(filtered.map((r) => r.id), ['incidentLinked']);
    },
  );

  test('findings on another diver\'s gear are not counted', () async {
    // equipment_findings has no diver_id, so an unscoped read pulls in
    // every profile on the device and reports a count this diver has no
    // way to act on.
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    final repo = EquipmentRepository();
    final mine = await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'My reg',
        type: EquipmentType.regulator,
        diverId: 'me',
      ),
    );
    final theirs = await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Their reg',
        type: EquipmentType.regulator,
        diverId: 'other',
      ),
    );
    final findings = EquipmentFindingsRepository(db: db);
    for (final id in [mine.id, theirs.id]) {
      await findings.saveReview(
        equipmentId: id,
        inputFingerprint: 'fp-$id',
        findings: [finding(id, ConditionRuleId.issueRecurring)],
        engineVersion: 1,
        now: DateTime(2026, 2),
      );
    }

    final scoped = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
    );
    addTearDown(scoped.dispose);
    final ranking = await scoped.read(findingsByRuleProvider(en).future);
    expect(ranking.single.count, 1);
  });

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
    final ranking = await container.read(issueTagRankingProvider(en).future);
    expect(ranking.map((r) => '${r.id}:${r.count}'), [
      'freeFlow:2',
      'hardBreathing:1',
    ]);
    expect(ranking.first.name, 'Free flow');

    // Keyed by the locale the page renders in, not the stored setting:
    // on "system" the platform language can change under the setting.
    final german = await container.read(
      issueTagRankingProvider(const Locale('de')).future,
    );
    expect(
      german.first.name,
      lookupAppLocalizations(
        const Locale('de'),
      ).equipmentObservation_tag_freeFlow,
    );
    expect(german.first.name, isNot('Free flow'));
  });

  group('with the statistics filter on', () {
    // The page's filter bar scopes every other card; the exposure and
    // reported-issue rankings follow it, so the page never mixes totals
    // over different dives.
    setUp(() {
      container.read(statisticsFilterProvider.notifier).state = DiveFilterState(
        startDate: DateTime(2026, 1, 2),
        endDate: DateTime(2026, 1, 4),
      );
    });

    test('exposure counts only the dives the filter keeps', () async {
      final ranking = await container.read(exposureRankingProvider(en).future);
      // Reg keeps r2 and r3 (two hours); BCD keeps b1 (one hour).
      expect(ranking.map((r) => '${r.id}:${r.count}'), [
        '${reg.id}:2',
        '${bcd.id}:1',
      ]);
    });

    test('a gear link on an existing dive reaches the filtered set', () async {
      // The filter reads the link tables, not just `dives`: linking the
      // BCD to r1 must put r1 in the set without any dive row changing.
      container.read(statisticsFilterProvider.notifier).state = DiveFilterState(
        equipmentIds: [bcd.id],
      );
      final sub = container.listen(
        statisticsFilteredDiveIdsProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(await container.read(statisticsFilteredDiveIdsProvider.future), {
        'b1',
        'b2',
      });

      await link('r1', bcd.id);
      Set<String>? ids;
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        ids = await container.read(statisticsFilteredDiveIdsProvider.future);
        if (ids!.contains('r1')) break;
      }
      expect(ids, {'b1', 'b2', 'r1'});
    });

    test('reported issues count only check-ins on those dives', () async {
      final observations = EquipmentObservationRepository();
      await observations.create(
        equipmentId: reg.id,
        diveId: 'r1',
        observedAt: DateTime(2026, 1, 1),
        status: ObservationStatus.issue,
        issueTags: const [ObservationTag.freeFlow],
      );
      await observations.create(
        equipmentId: reg.id,
        diveId: 'r2',
        observedAt: DateTime(2026, 1, 2),
        status: ObservationStatus.issue,
        issueTags: const [ObservationTag.leak],
      );
      // A bench check-in belongs to no dive, so no dive filter keeps it.
      await observations.create(
        equipmentId: reg.id,
        observedAt: DateTime(2026, 1, 3),
        status: ObservationStatus.issue,
        issueTags: const [ObservationTag.hoseDamage],
      );
      final ranking = await container.read(issueTagRankingProvider(en).future);
      expect(ranking.map((r) => r.id), ['leak']);
    });
  });
}
