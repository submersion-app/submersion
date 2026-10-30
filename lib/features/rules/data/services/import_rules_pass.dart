import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

final _log = LoggerService.forClass(ImportRulesOutcome);

/// What the rules did after one import (#3513).
class ImportRulesOutcome {
  const ImportRulesOutcome({
    this.runs = const [],
    this.failed = false,
    this.skippedRules = const [],
    this.skippedActions = const [],
  });

  /// One run per diver whose rules changed something.
  final List<RuleRunResult> runs;

  /// The rules could not run; the import itself still stands.
  final bool failed;

  /// Rules that could not run, and rules with an action naming a deleted
  /// item, across every profile's run, those that changed nothing too: the
  /// import's results say so (#3513).
  final List<String> skippedRules;
  final List<String> skippedActions;
}

/// Runs each diver's after-import rules over the dives and sites [result]
/// created: every profile of a multi-diver import over its own items, or
/// [activeDiverId] over the import's. Never throws; a failure is reported
/// in the outcome so the import is kept.
Future<ImportRulesOutcome> runImportRules(
  RuleEngine engine,
  UnifiedImportResult result, {
  required String? activeDiverId,
  required String sourceLabel,
  bool Function()? isCancelled,
}) async {
  final targets = result.diverOutcomes.isNotEmpty
      ? [
          for (final o in result.diverOutcomes)
            (diverId: o.diverId, dives: o.diveIds, sites: o.siteIds),
        ]
      : [
          if (activeDiverId != null)
            (
              diverId: activeDiverId,
              dives: result.importedDiveIds,
              sites: result.importedSiteIds,
            ),
        ];
  final runs = <RuleRunResult>[];
  final skippedRules = <String>{};
  final skippedActions = <String>{};
  try {
    for (final t in targets) {
      // A Cancel during the pass stops it before the next profile's run;
      // a run already under way is one transaction, and stays.
      if (isCancelled?.call() ?? false) break;
      if (t.dives.isEmpty && t.sites.isEmpty) continue;
      final run = await engine.run(
        RuleRunRequest(
          diverId: t.diverId,
          trigger: RuleRunTrigger.imported,
          sourceLabel: sourceLabel,
          targets: {
            if (t.dives.isNotEmpty) RuleSubject.dives: t.dives.toSet(),
            if (t.sites.isNotEmpty) RuleSubject.sites: t.sites.toSet(),
          },
        ),
      );
      if (run.changedAnything) runs.add(run);
      skippedRules.addAll(run.skippedRuleNames);
      skippedActions.addAll(run.skippedActionRuleNames);
    }
    return ImportRulesOutcome(
      runs: runs,
      skippedRules: skippedRules.toList(),
      skippedActions: skippedActions.toList(),
    );
  } catch (e, st) {
    _log.error('Rules could not run after import', error: e, stackTrace: st);
    return ImportRulesOutcome(
      runs: runs,
      failed: true,
      skippedRules: skippedRules.toList(),
      skippedActions: skippedActions.toList(),
    );
  }
}
