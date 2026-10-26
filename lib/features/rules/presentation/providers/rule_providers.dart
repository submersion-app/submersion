import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/data/services/rule_target_labels.dart';
import 'package:submersion/features/rules/data/services/rule_target_scope.dart';
import 'package:submersion/features/rules/data/services/rule_undo_service.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';

// no-tick: a stateless repository handle; readers subscribe to its ticks.
final ruleRepositoryProvider = Provider<RuleRepository>(
  (ref) => RuleRepository(),
);

// no-tick: a stateless repository handle; readers subscribe to its ticks.
final ruleRunRepositoryProvider = Provider<RuleRunRepository>(
  (ref) => RuleRunRepository(),
);

// no-tick: a stateless service; callers read it on demand.
final ruleTargetScopeProvider = Provider<RuleTargetScope>(
  (ref) => RuleTargetScope(),
);

/// [diverId]'s names: the active profile's live index, or another
/// profile's own (its rules, from a multi-diver import, and its runs name
/// that profile's tags, buddies and gear).
Future<NameIndex> ruleNamesFor(Ref ref, String diverId) async {
  final active = await ref.read(validatedCurrentDiverIdProvider.future);
  if (diverId == active) return ref.read(queryNameIndexProvider.future);
  return NameIndexLoader(
    DatabaseService.instance.database,
  ).load(diverId: diverId, l10n: l10nForLocaleTag(ref.read(localeProvider)));
}

// no-tick: a stateless service; each run reads the live name index.
final ruleEngineProvider = Provider<RuleEngine>(
  (ref) => RuleEngine(
    rules: ref.watch(ruleRepositoryProvider),
    runs: ref.watch(ruleRunRepositoryProvider),
    scope: ref.watch(ruleTargetScopeProvider),
    names: (diverId) => ruleNamesFor(ref, diverId),
  ),
);

// no-tick: a stateless service; callers read it on demand.
final ruleUndoServiceProvider = Provider<RuleUndoService>(
  (ref) => RuleUndoService(
    runs: ref.watch(ruleRunRepositoryProvider),
    scope: ref.watch(ruleTargetScopeProvider),
  ),
);

/// The active diver's rules for one subject, in run order (#3513).
/// Refreshes on any rules write, including a sync applying a remote row,
/// and when the name index changes (a deleted tag breaks an action).
final rulesProvider = FutureProvider.autoDispose
    .family<List<Rule>, RuleSubject>((ref, subject) async {
      final repository = ref.watch(ruleRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchRulesChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final names = await ref.watch(queryNameIndexProvider.future);
      if (diverId == null) return const [];
      return repository.getAll(
        subject: subject,
        diverId: diverId,
        names: names,
      );
    });

/// The active diver's rule runs, newest first.
final ruleRunsProvider = FutureProvider.autoDispose<List<RuleRun>>((ref) async {
  final repository = ref.watch(ruleRunRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchRunsChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return const [];
  return repository.getRuns(diverId);
});

/// The runs named by [idsKey] (comma-joined ids), whichever profile each
/// belongs to, newest first.
final ruleRunsByIdsProvider = FutureProvider.autoDispose
    .family<List<RuleRun>, String>((ref, idsKey) async {
      final repository = ref.watch(ruleRunRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchRunsChanges());
      return repository.getRunsByIds(idsKey.split(','));
    });

/// Looks ids up to names through the live name index, for action summaries
/// and change lists.
final ruleNameOfProvider = FutureProvider.autoDispose<RuleNameOf>((ref) async {
  final names = await ref.watch(queryNameIndexProvider.future);
  return (QuerySubject subject, String id) => names.labelOf(subject, id);
});

/// One rule by id, for the editor. The editor seeds itself from the first
/// value and ignores later ticks.
final ruleByIdProvider = FutureProvider.autoDispose.family<Rule?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(ruleRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchRulesChanges());
  final names = await ref.watch(queryNameIndexProvider.future);
  return repository.getById(id, names: names);
});

/// How many of the diver's dives or sites a condition matches, keyed by
/// the subject and the condition's stored JSON (empty for no condition).
/// Each keystroke that parses is a new key, so a key counts only once it
/// has stood for the dive list's debounce: one the diver typed past is
/// disposed first and never queries.
final ruleMatchCountProvider = FutureProvider.autoDispose
    .family<int?, ({RuleSubject subject, String conditionJson})>((
      ref,
      key,
    ) async {
      final settled = Completer<void>();
      final timer = Timer(
        QueryIdSetRunner.changeTickDebounce,
        settled.complete,
      );
      ref.onDispose(timer.cancel);
      await settled.future;
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return null;
      final condition = decodeRuleCondition(key.conditionJson);
      try {
        return await ref
            .read(ruleTargetScopeProvider)
            .countMatches(condition, key.subject, diverId);
      } on Object {
        // A half-typed condition the compiler rejects shows no count.
        return null;
      }
    });

/// One run with its changes, what identifies each changed item, and the
/// names of its own profile (a run of another profile, from a multi-diver
/// import, names that profile's tags, buddies and gear).
final ruleRunDetailProvider = FutureProvider.autoDispose
    .family<
      ({
        RuleRun? run,
        List<RuleChange> changes,
        Map<String, RuleTargetInfo> targets,
        RuleNameOf nameOf,
      }),
      String
    >((ref, runId) async {
      final repository = ref.watch(ruleRunRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchRunsChanges());
      final active = await ref.watch(queryNameIndexProvider.future);
      final run = await repository.getRun(runId);
      final diverId = run?.diverId;
      final names = diverId == null ? active : await ruleNamesFor(ref, diverId);
      final changes = await repository.getChanges(runId);
      final labels = RuleTargetLabels();
      final targets = <String, RuleTargetInfo>{
        for (final s in RuleSubject.values)
          ...await labels.infoFor(s, {
            for (final c in changes)
              if (c.subject == s) c.targetId,
          }),
      };
      return (
        run: run,
        changes: changes,
        targets: targets,
        nameOf: (QuerySubject subject, String id) => names.labelOf(subject, id),
      );
    });
