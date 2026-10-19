import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/device_display_name_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/dive_rule_applier.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/data/services/rule_target_scope.dart';
import 'package:submersion/features/rules/data/services/site_rule_applier.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// Carries a preview's result out of the transaction it rolls back.
class _RollbackPreview implements Exception {
  const _RollbackPreview(this.result);

  final RuleRunResult result;
}

/// Runs a diver's logbook rules (#3513): dive rules then site rules, each
/// subject's rules top to bottom, every rule matched against the database
/// as the rules before it left it. One transaction per run. A preview is
/// the same pass rolled back, so it cannot disagree with the run.
class RuleEngine {
  RuleEngine({
    RuleRepository? rules,
    RuleRunRepository? runs,
    RuleTargetScope? scope,
    DiveRuleApplier? dives,
    SiteRuleApplier? sites,
    required Future<NameIndex> Function() names,
    Future<String?> Function()? deviceLabel,
  }) : _rules = rules ?? RuleRepository(),
       _runs = runs ?? RuleRunRepository(),
       _scope = scope ?? RuleTargetScope(),
       _dives = dives ?? DiveRuleApplier(),
       _sites = sites ?? SiteRuleApplier(),
       _names = names,
       _deviceLabel =
           deviceLabel ?? (() => const DeviceDisplayNameService().resolve());

  final RuleRepository _rules;
  final RuleRunRepository _runs;
  final RuleTargetScope _scope;
  final DiveRuleApplier _dives;
  final SiteRuleApplier _sites;
  final Future<NameIndex> Function() _names;
  final Future<String?> Function() _deviceLabel;

  AppDatabase get _db => DatabaseService.instance.database;

  /// This device's name, asked of the platform once and only when a run
  /// records history (a hand-saved dive with no rule changes asks nothing).
  Future<String?>? _deviceName;

  Future<String?> _device() => _deviceName ??= _deviceLabel();

  /// What [request] would change, without changing anything.
  Future<RuleRunResult> preview(RuleRunRequest request) async {
    try {
      return await _db.transaction<RuleRunResult>(() async {
        throw _RollbackPreview(await _pass(request));
      });
    } on _RollbackPreview catch (p) {
      return p.result;
    }
  }

  /// Applies [request] and records it in the history when it changed
  /// something.
  Future<RuleRunResult> run(RuleRunRequest request) async {
    final result = await _db.transaction(() async {
      final pass = await _pass(request);
      if (!pass.changedAnything) return pass;
      final runId = await _runs.insertRun(
        diverId: request.diverId,
        trigger: request.trigger,
        sourceLabel: request.sourceLabel,
        deviceLabel: await _device(),
        changes: pass.changes,
      );
      return RuleRunResult(
        runId: runId,
        changes: pass.changes,
        changedTargetCount: pass.changedTargetCount,
        changedCountByRule: pass.changedCountByRule,
        skippedRuleNames: pass.skippedRuleNames,
        skippedActionRuleNames: pass.skippedActionRuleNames,
        targetCount: pass.targetCount,
        outOfScopeCount: pass.outOfScopeCount,
        ruleCount: pass.ruleCount,
      );
    });
    if (result.changedAnything) SyncEventBus.notifyLocalChange();
    return result;
  }

  bool _selected(Rule rule, RuleRunRequest request) {
    final only = request.onlyRuleIds;
    if (only != null) return only.contains(rule.id);
    if (!rule.enabled) return false;
    return switch (request.trigger) {
      RuleRunTrigger.imported => rule.triggers.contains(
        RuleTrigger.afterImport,
      ),
      RuleRunTrigger.createdByHand => rule.triggers.contains(
        RuleTrigger.afterManualCreate,
      ),
      RuleRunTrigger.onDemandAll || RuleRunTrigger.onDemandSelection => true,
    };
  }

  Future<RuleRunResult> _pass(RuleRunRequest request) async {
    final names = await _names();
    final changes = <RuleChange>[];
    final byRule = <String, Set<String>>{};
    final skipped = <String>[];
    final skippedActions = <String>{};
    var targetCount = 0;
    var outOfScope = 0;
    var ruleCount = 0;
    for (final subject in RuleSubject.values) {
      if (!request.targets.containsKey(subject)) continue;
      final rules = [
        for (final r in await _rules.getAll(
          subject: subject,
          diverId: request.diverId,
          names: names,
        ))
          if (_selected(r, request)) r,
      ];
      if (rules.isEmpty) continue;
      final requested = request.targets[subject];
      final eligible = requested == null
          ? await _scope.allEligibleIds(subject, request.diverId)
          : await _scope.matches(null, subject, request.diverId, requested);
      targetCount += eligible.length;
      outOfScope += (requested?.length ?? eligible.length) - eligible.length;
      if (eligible.isEmpty) continue;
      for (final rule in rules) {
        if (!rule.isRunnable) {
          skipped.add(rule.name);
          continue;
        }
        ruleCount++;
        final matched = await _scope.matches(
          rule.condition,
          subject,
          request.diverId,
          eligible,
        );
        if (matched.isEmpty) continue;
        final ids = matched.toList()..sort();
        for (final action in rule.actions) {
          final AppliedAction applied = subject == RuleSubject.dives
              ? await _dives.apply(rule, action, ids)
              : await _sites.apply(rule, action, ids);
          if (applied.skippedMissingRef) skippedActions.add(rule.name);
          for (final c in applied.changes) {
            changes.add(c);
            byRule.putIfAbsent(rule.name, () => {}).add(c.targetId);
          }
        }
      }
    }
    return RuleRunResult(
      runId: null,
      changes: changes,
      changedTargetCount: {
        for (final c in changes) '${c.subject.name}:${c.targetId}',
      }.length,
      changedCountByRule: {
        for (final e in byRule.entries) e.key: e.value.length,
      },
      skippedRuleNames: skipped,
      skippedActionRuleNames: skippedActions.toList(),
      targetCount: targetCount,
      outOfScopeCount: outOfScope,
      ruleCount: ruleCount,
    );
  }
}
