import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/services/import_rules_pass.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

import '../../../../helpers/test_database.dart';
import '../../../rules/rules_fixture.dart';

class _Adapter implements ImportSourceAdapter {
  _Adapter(this.result);

  final UnifiedImportResult result;

  @override
  void resetState() {}
  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;
  @override
  String get displayName => 'Perdix 2';
  @override
  String get defaultTagName => 'Perdix 2 Import';
  @override
  List<WizardStepDef> get acquisitionSteps => [];
  @override
  Set<DuplicateAction> get supportedDuplicateActions => {DuplicateAction.skip};
  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;
  @override
  Future<ImportBundle> buildBundle() => throw UnimplementedError();
  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) =>
      throw UnimplementedError();
  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async => result;
}

/// Counts the runs it makes.
class _CountingEngine extends RuleEngine {
  _CountingEngine(this.onRun) : super(names: (_) async => NameIndex(const []));

  final void Function() onRun;

  @override
  Future<RuleRunResult> run(RuleRunRequest request) async {
    final result = await super.run(request);
    onRun();
    return result;
  }
}

const _bundle = ImportBundle(
  source: ImportSourceInfo(type: ImportSourceType.uddf, displayName: 'x.uddf'),
  groups: {},
);

void main() {
  late AppDatabase db;
  late RuleEngine engine;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me', 'other']);
    await seedRuleDive(db, 'd20', maxDepth: 20);
    await seedRuleDive(db, 'd35', maxDepth: 35);
    await seedRuleDive(db, 'o40', diver: 'other', maxDepth: 40);
    await seedRuleSite(db, 's1');
    engine = RuleEngine(names: (_) async => NameIndex(const []));
  });
  tearDown(tearDownTestDatabase);

  Future<void> deepRule(String diver) => RuleRepository().create(
    diverId: diver,
    subject: RuleSubject.dives,
    name: 'Deep',
    triggers: const {RuleTrigger.afterImport},
    condition: depthOver(30),
    actions: const [
      DiveMembershipAction(DiveCollection.diveTypes, MembershipMode.add, [
        'deep',
      ]),
    ],
  );

  ImportWizardNotifier notifier(UnifiedImportResult result) =>
      ImportWizardNotifier(_Adapter(result), ruleEngine: engine)
        ..setDiverId('me')
        ..setBundle(_bundle);

  const imported = UnifiedImportResult(
    importedCounts: {ImportEntityType.dives: 2},
    consolidatedCount: 0,
    skippedCount: 0,
    importedDiveIds: ['d20', 'd35'],
    importedSiteIds: ['s1'],
  );

  test('an after-import rule tags the deep dive and is reported', () async {
    await deepRule('me');
    final n = notifier(imported);
    await n.performImport();
    expect(await ruleDiveTypes(db, 'd35'), ['deep', 'recreational']);
    expect(await ruleDiveTypes(db, 'd20'), isEmpty);
    expect(n.state.ruleRuns.single.changedTargetCount, 1);
    expect(n.state.ruleRuns.single.runId, isNotNull);
    expect(n.state.rulesFailed, isFalse);
  });

  test('no rules: no runs, nothing changed', () async {
    final n = notifier(imported);
    await n.performImport();
    expect(n.state.ruleRuns, isEmpty);
    expect(await ruleDiveTypes(db, 'd35'), isEmpty);
  });

  test('a cancelled import runs no rules', () async {
    await deepRule('me');
    final n = notifier(imported);
    final run = n.performImport();
    n.cancelImport();
    await run;
    expect(await ruleDiveTypes(db, 'd35'), isEmpty);
  });

  test(
    'a cancel during the rules pass stops before the next profile',
    () async {
      await deepRule('me');
      await deepRule('other');
      var ran = 0;
      final outcome = await runImportRules(
        _CountingEngine(() => ran++),
        const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 3},
          consolidatedCount: 0,
          skippedCount: 0,
          importedDiveIds: ['d20', 'd35'],
          diverOutcomes: [
            DiverImportOutcome(
              diverId: 'me',
              name: 'me',
              isNew: false,
              isActive: true,
              diveIds: ['d20', 'd35'],
            ),
            DiverImportOutcome(
              diverId: 'other',
              name: 'other',
              isNew: false,
              isActive: false,
              diveIds: ['o40'],
            ),
          ],
        ),
        activeDiverId: 'me',
        sourceLabel: 'Perdix 2',
        // The diver taps Cancel while the first profile's rules run.
        isCancelled: () => ran >= 1,
      );
      expect(outcome.runs, hasLength(1));
      expect(await ruleDiveTypes(db, 'o40'), isEmpty);
    },
  );

  test('a rules failure keeps the import and flags it', () async {
    await deepRule('me');
    await db.customStatement('DROP TABLE rule_run_changes');
    final n = notifier(imported);
    await n.performImport();
    expect(n.state.importResult, isNotNull);
    expect(n.state.rulesFailed, isTrue);
  });

  test(
    'a multi-diver import runs each diver\'s rules on their dives',
    () async {
      await deepRule('me');
      await deepRule('other');
      final n = notifier(
        const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 3},
          consolidatedCount: 0,
          skippedCount: 0,
          importedDiveIds: ['d20', 'd35'],
          diverOutcomes: [
            DiverImportOutcome(
              diverId: 'me',
              name: 'me',
              isNew: false,
              isActive: true,
              diveIds: ['d20', 'd35'],
            ),
            DiverImportOutcome(
              diverId: 'other',
              name: 'other',
              isNew: false,
              isActive: false,
              diveIds: ['o40'],
            ),
          ],
        ),
      );
      await n.performImport();
      expect(await ruleDiveTypes(db, 'd35'), ['deep', 'recreational']);
      expect(await ruleDiveTypes(db, 'o40'), ['deep', 'recreational']);
      expect(n.state.ruleRuns, hasLength(2));
    },
  );
}
