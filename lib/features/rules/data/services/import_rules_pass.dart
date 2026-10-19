import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

final _log = LoggerService.forClass(ImportRulesOutcome);

/// What the rules did after one import (#3513).
class ImportRulesOutcome {
  const ImportRulesOutcome({this.runs = const [], this.failed = false});

  /// One run per diver whose rules changed something.
  final List<RuleRunResult> runs;

  /// The rules could not run; the import itself still stands.
  final bool failed;
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
  try {
    for (final t in targets) {
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
    }
    return ImportRulesOutcome(runs: runs);
  } catch (e, st) {
    _log.error('Rules could not run after import', error: e, stackTrace: st);
    return ImportRulesOutcome(runs: runs, failed: true);
  }
}
