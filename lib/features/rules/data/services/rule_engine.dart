import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/device_display_name_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
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
    required Future<NameIndex> Function(String diverId) names,
    Future<String?> Function()? deviceLabel,
    Future<void> Function(String diverId, Iterable<String> diveIds)?
    ensureDerived,
    void Function(Iterable<String> diveIds)? afterDiveWrites,
  }) : _rules = rules ?? RuleRepository(),
       _runs = runs ?? RuleRunRepository(),
       _scope = scope ?? RuleTargetScope(),
       _dives = dives ?? DiveRuleApplier(),
       _sites = sites ?? SiteRuleApplier(),
       _names = names,
       _deviceLabel =
           deviceLabel ?? (() => const DeviceDisplayNameService().resolve()),
       _ensureDerived = ensureDerived ?? ensureDerivedCurrent,
       _afterDiveWrites = afterDiveWrites ?? refreshAfterRuleWrites;

  final RuleRepository _rules;
  final RuleRunRepository _runs;
  final RuleTargetScope _scope;
  final DiveRuleApplier _dives;
  final SiteRuleApplier _sites;
  final Future<NameIndex> Function(String diverId) _names;
  final Future<String?> Function() _deviceLabel;
  final Future<void> Function(String diverId, Iterable<String> diveIds)
  _ensureDerived;
  final void Function(Iterable<String> diveIds) _afterDiveWrites;

  /// Rebuilds the derived fields of those of [diverId]'s [diveIds] whose
  /// stored ones are missing or stale, found in one query over the diver's
  /// dives rather than checked one by one (a run over a whole logbook
  /// judges every dive).
  static Future<void> ensureDerivedCurrent(
    String diverId,
    Iterable<String> diveIds, [
    DerivedMetricsRepository? repository,
  ]) async {
    final metrics = repository ?? DerivedMetricsRepository();
    final stale = (await metrics.staleDiveIds(diverId: diverId)).toSet();
    for (final id in diveIds) {
      if (stale.contains(id)) await metrics.ensureCurrent(id);
    }
  }

  AppDatabase get _db => DatabaseService.instance.database;

  /// This device's name, asked of the platform once per engine and always
  /// before a transaction opens: nothing awaited inside the transaction may
  /// need the connection from outside it.
  Future<String?>? _deviceName;

  Future<String?> _device() => _deviceName ??= _deviceLabel();

  /// What [request] would change, without changing anything.
  Future<RuleRunResult> preview(RuleRunRequest request) async {
    if (!await _anySelected(request)) return RuleRunResult.noRules;
    // Resolved before the transaction: a name index rebuilding outside it
    // would queue behind the transaction's lock while the transaction
    // waited for it.
    final names = await _names(request.diverId);
    final rules = await _load(request, names);
    await _prepareDerived(request, rules);
    try {
      return await _db.transaction<RuleRunResult>(() async {
        throw _RollbackPreview(await _pass(request, rules));
      });
    } on _RollbackPreview catch (p) {
      return p.result;
    }
  }

  /// Applies [request] and records it in the history when it changed
  /// something.
  Future<RuleRunResult> run(RuleRunRequest request) async {
    // Nothing would run: answered before names, the device or a
    // transaction, so a logbook with no rule for this costs one small
    // query (a fresh install behaves as before rules existed).
    if (!await _anySelected(request)) return RuleRunResult.noRules;
    // All resolved before the transaction (see [preview]).
    final names = await _names(request.diverId);
    final device = await _device();
    final rules = await _load(request, names);
    await _prepareDerived(request, rules);
    final result = await _db.transaction(() async {
      final pass = await _pass(request, rules);
      if (!pass.changedAnything) return pass;
      final runId = await _runs.insertRun(
        diverId: request.diverId,
        trigger: request.trigger,
        sourceLabel: request.sourceLabel,
        deviceLabel: device,
        changes: pass.changes,
      );
      return pass.copyWith(runId: runId);
    });
    if (result.changedAnything) {
      SyncEventBus.notifyLocalChange();
      _afterDiveWrites({
        for (final c in result.changes)
          if (c.subject == RuleSubject.dives) c.targetId,
      });
    }
    return result;
  }

  /// Derived dive fields (SAC trend, final stop...) are stored by a
  /// scheduler that runs after a dive is written, which the rules on an
  /// import's or a new dive's can outpace. When a rule about to run reads
  /// them, the dives it will judge get them computed first, outside the
  /// transaction (as the names are).
  Future<void> _prepareDerived(
    RuleRunRequest request,
    Map<RuleSubject, List<Rule>> rules,
  ) async {
    final reads = (rules[RuleSubject.dives] ?? const <Rule>[]).any(
      (r) =>
          r.isRunnable &&
          _scope.reads(
            r.condition,
            RuleSubject.dives,
            request.diverId,
            kDiveDerivedMetricsTable,
          ),
    );
    if (!reads) return;
    final requested = request.targets[RuleSubject.dives];
    await _ensureDerived(
      request.diverId,
      requested == null
          ? await _scope.allEligibleIds(RuleSubject.dives, request.diverId)
          : await _scope.matches(
              null,
              RuleSubject.dives,
              request.diverId,
              requested,
            ),
    );
  }

  bool _selected(Rule rule, RuleRunRequest request) =>
      _selects(rule.id, rule.enabled, rule.triggers, request);

  bool _selects(
    String id,
    bool enabled,
    Set<RuleTrigger> triggers,
    RuleRunRequest request,
  ) {
    final only = request.onlyRuleIds;
    if (only != null) return only.contains(id);
    if (!enabled) return false;
    return switch (request.trigger) {
      RuleRunTrigger.imported => triggers.contains(RuleTrigger.afterImport),
      RuleRunTrigger.createdByHand => triggers.contains(
        RuleTrigger.afterManualCreate,
      ),
      RuleRunTrigger.onDemandAll || RuleRunTrigger.onDemandSelection => true,
    };
  }

  /// Whether any of the diver's rules would run for [request], from the
  /// stored rows alone (no condition or action is read).
  Future<bool> _anySelected(RuleRunRequest request) async {
    for (final row in await _rules.rowsFor(request.diverId)) {
      final subject = RuleSubject.values.asNameMap()[row.subject];
      if (subject != null &&
          request.targets.containsKey(subject) &&
          _selects(
            row.id,
            row.enabled,
            parseRuleTriggers(row.triggers),
            request,
          )) {
        return true;
      }
    }
    return false;
  }

  /// The diver's rules that [request] runs, per requested subject, in run
  /// order. Loaded once, before the transaction, for both the derived
  /// fields check and the pass (a run writes no rules).
  Future<Map<RuleSubject, List<Rule>>> _load(
    RuleRunRequest request,
    NameIndex names,
  ) async => {
    for (final subject in RuleSubject.values)
      if (request.targets.containsKey(subject))
        subject: [
          for (final r in await _rules.getAll(
            subject: subject,
            diverId: request.diverId,
            names: names,
          ))
            if (_selected(r, request)) r,
        ],
  };

  Future<RuleRunResult> _pass(
    RuleRunRequest request,
    Map<RuleSubject, List<Rule>> selected,
  ) async {
    final changes = <RuleChange>[];
    final byRule = <String, Set<String>>{};
    final skipped = <String>[];
    final skippedActions = <String>{};
    var targetCount = 0;
    var outOfScope = 0;
    for (final MapEntry(key: subject, value: rules) in selected.entries) {
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
    );
  }
}
