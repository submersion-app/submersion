import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
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

// no-tick: a stateless service; each run reads the live name index.
final ruleEngineProvider = Provider<RuleEngine>(
  (ref) => RuleEngine(names: () => ref.read(queryNameIndexProvider.future)),
);

// no-tick: a stateless service; callers read it on demand.
final ruleUndoServiceProvider = Provider<RuleUndoService>(
  (ref) => RuleUndoService(),
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
final ruleMatchCountProvider = FutureProvider.autoDispose
    .family<int?, ({RuleSubject subject, String conditionJson})>((
      ref,
      key,
    ) async {
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
