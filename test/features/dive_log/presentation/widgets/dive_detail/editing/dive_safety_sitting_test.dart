import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_safety_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// Safety findings dismissed and restored in a sitting, written at Save
/// (issue #4527, plan 6).
void main() {
  late SafetyFindingsRepository repo;
  late ProviderContainer container;
  late Dive dive;
  late SafetyFinding rapid;
  late SafetyFinding deco;
  final now = DateTime.utc(2026, 7, 16);

  SafetyFinding finding(String id, SafetyRuleId rule, int start) =>
      SafetyFinding(
        id: id,
        diveId: 'd1',
        ruleId: rule,
        severity: SafetySeverity.caution,
        startTimestamp: start,
        endTimestamp: start + 40,
        value: 14.2,
        engineVersion: 1,
        createdAt: now,
      );

  setUp(() async {
    await setUpTestDatabase();
    repo = SafetyFindingsRepository();
    container = ProviderContainer();
    dive = await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1'),
    );
    await repo.saveReview(
      SafetyReview(
        diveId: 'd1',
        engineVersion: 1,
        reviewedAt: now,
        findings: [
          finding('f1', SafetyRuleId.rapidAscent, 100),
          finding('f2', SafetyRuleId.missedDecoStop, 600),
        ],
      ),
    );
    final stored = (await repo.getReview('d1'))!.findings;
    rapid = stored.firstWhere((f) => f.ruleId == SafetyRuleId.rapidAscent);
    deco = stored.firstWhere((f) => f.ruleId == SafetyRuleId.missedDecoStop);
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  EditSession<Dive> started() {
    final session = EditSession<Dive>(dive);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    holdSafetyDismissals(session, container.read);
    return session;
  }

  Future<SafetyFinding> storedOf(String id) async =>
      (await repo.getReview('d1'))!.findings.firstWhere((f) => f.id == id);

  test('a finding dismissed and restored again is no change', () {
    final session = started();
    setFindingDismissed(session, rapid, dismissed: true);
    expect(session.changedCardIds, {'safetyReview'});
    setFindingDismissed(session, rapid, dismissed: false);
    expect(session.isDirty, isFalse);
  });

  test(
    'dismissed in the sitting: written at Save; Cancel writes nothing',
    () async {
      final session = started();
      setFindingDismissed(session, rapid, dismissed: true);
      expect((await storedOf(rapid.id)).isDismissed, isFalse);

      await session.runHeldWrites();
      expect((await storedOf(rapid.id)).isDismissed, isTrue);

      final other = started();
      setFindingDismissed(other, deco, dismissed: true);
      other.dispose();
      expect((await storedOf(deco.id)).isDismissed, isFalse);
    },
  );

  test('dismiss all, then the sitting shows them dismissed', () {
    final session = started();
    setAllFindingsDismissed(session, [rapid, deco], dismissed: true);
    final review = SafetyReview(
      diveId: 'd1',
      engineVersion: 1,
      reviewedAt: now,
      findings: [rapid, deco],
    );
    expect(
      reviewInSitting(session, review).findings.every((f) => f.isDismissed),
      isTrue,
    );
    expect(sittingDismissals(session), {rapid.id: true, deco.id: true});
  });

  test('a finding that stopped firing before Save is skipped', () async {
    final session = started();
    setFindingDismissed(session, rapid, dismissed: true);
    // A recompute drops the rapid ascent.
    await repo.saveReview(
      SafetyReview(
        diveId: 'd1',
        engineVersion: 1,
        reviewedAt: now,
        findings: [finding('f2', SafetyRuleId.missedDecoStop, 600)],
      ),
    );

    await session.runHeldWrites();
    final findings = (await repo.getReview('d1'))!.findings;
    expect(findings.map((f) => f.ruleId), [SafetyRuleId.missedDecoStop]);
  });
}
