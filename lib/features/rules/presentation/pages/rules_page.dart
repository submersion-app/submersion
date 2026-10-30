import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/features/rules/presentation/widgets/rules_page_menus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/fab_clearance.dart';

final _log = LoggerService.forClass(RulesPage);

/// Settings > Manage > Rules (#3513): the diver's dive rules and site rules,
/// each list in the order the rules run. A row opens the editor; its switch
/// turns automatic runs off; its menu runs, copies or deletes it.
class RulesPage extends ConsumerWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dives = ref.watch(rulesProvider(RuleSubject.dives));
    final sites = ref.watch(rulesProvider(RuleSubject.sites));
    final nameOf = ref.watch(ruleNameOfProvider);
    final hasRules =
        (dives.value?.isNotEmpty ?? false) ||
        (sites.value?.isNotEmpty ?? false);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rules_page_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: l10n.common_action_back,
        ),
        actions: [
          if (hasRules) const RunRulesMenuButton(),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.rules_action_history,
            onPressed: () => context.push('/rules/history'),
          ),
        ],
      ),
      floatingActionButton: hasRules
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/rules/new'),
              icon: const Icon(Icons.add),
              label: Text(l10n.rules_action_new),
            )
          : null,
      body: switch ((dives, sites, nameOf)) {
        (AsyncError(:final error, :final stackTrace), _, _) ||
        (_, AsyncError(:final error, :final stackTrace), _) ||
        (_, _, AsyncError(:final error, :final stackTrace)) => () {
          _log.error(
            'Failed to load rules',
            error: error,
            stackTrace: stackTrace,
          );
          return Center(child: Text(l10n.common_error_tryAgain));
        }(),
        // A reload (a synced tag or site refreshing the names) keeps its
        // previous value, so the lists stay up and their rows mounted
        // rather than flashing to a spinner.
        (
          AsyncValue(value: final d?),
          AsyncValue(value: final s?),
          AsyncValue(value: final n?),
        ) =>
          d.isEmpty && s.isEmpty
              ? const _EmptyRules()
              : _RuleLists(dives: d, sites: s, nameOf: n),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EmptyRules extends ConsumerWidget {
  const _EmptyRules();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // 30.48 m is 100 ft: a round example in either unit.
    final example = UnitFormatter(
      ref.watch(settingsProvider),
    ).formatDepth(30.48, decimals: 0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rule,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.rules_empty(example), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/rules/new'),
              icon: const Icon(Icons.add),
              label: Text(l10n.rules_action_new),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleLists extends ConsumerStatefulWidget {
  const _RuleLists({
    required this.dives,
    required this.sites,
    required this.nameOf,
  });

  final List<Rule> dives;
  final List<Rule> sites;
  final RuleNameOf nameOf;

  @override
  ConsumerState<_RuleLists> createState() => _RuleListsState();
}

class _RuleListsState extends ConsumerState<_RuleLists> {
  /// Local copies so a dropped row does not snap back while the write and
  /// the tick catch up.
  late List<Rule> _dives = List.unmodifiable(widget.dives);
  late List<Rule> _sites = List.unmodifiable(widget.sites);

  @override
  void didUpdateWidget(_RuleLists old) {
    super.didUpdateWidget(old);
    if (old.dives != widget.dives) _dives = List.unmodifiable(widget.dives);
    if (old.sites != widget.sites) _sites = List.unmodifiable(widget.sites);
  }

  Future<void> _reorder(List<Rule> list, int oldIndex, int newIndex) async {
    final moved = list[oldIndex];
    final rest = [
      for (var i = 0; i < list.length; i++)
        if (i != oldIndex) list[i],
    ];
    final reordered = [...rest.take(newIndex), moved, ...rest.skip(newIndex)];
    final dives = identical(list, _dives);
    void show(List<Rule> rules) => setState(() {
      if (dives) {
        _dives = rules;
      } else {
        _sites = rules;
      }
    });
    show(reordered);
    try {
      await ref.read(ruleRepositoryProvider).reorder([
        for (final r in reordered) r.id,
      ]);
    } catch (e, st) {
      _log.error('Failed to reorder rules', error: e, stackTrace: st);
      if (!mounted) return;
      // Nothing was stored: back to the stored order, as last loaded (a
      // sync may have landed while the write ran).
      show(List.unmodifiable(dives ? widget.dives : widget.sites));
      showRulesError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CustomScrollView(
      slivers: [
        if (_dives.isNotEmpty) ...[
          _header(context, l10n.rules_section_dives),
          _section(_dives),
        ],
        if (_sites.isNotEmpty) ...[
          _header(context, l10n.rules_section_sites),
          _section(_sites),
        ],
        const SliverPadding(padding: kFabListPadding),
      ],
    );
  }

  Widget _header(BuildContext context, String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );

  Widget _section(List<Rule> list) => SliverReorderableList(
    itemCount: list.length,
    onReorderItem: (a, b) => _reorder(list, a, b),
    itemBuilder: (context, i) => _RuleTile(
      key: ValueKey(list[i].id),
      rule: list[i],
      index: i,
      nameOf: widget.nameOf,
    ),
  );
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile({
    super.key,
    required this.rule,
    required this.index,
    required this.nameOf,
  });

  final Rule rule;
  final int index;
  final RuleNameOf nameOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final prefs = ref.watch(queryUnitPrefsProvider);
    final problem = ruleProblemText(l10n, rule);
    final broken = rule.actions.any((a) => ruleActionIsBroken(a, nameOf));
    // A condition that did not load is not "every dive": the problem line
    // below says what is wrong, as the saved-queries page does.
    final condition = rule.condition != null
        ? QueryPrinter(
            appQueryRegistry,
            appQueryRegistry.entityFor(rule.subject.querySubject),
            prefs,
          ).print(rule.condition!)
        : rule.conditionJson.isNotEmpty
        ? null
        : rule.subject == RuleSubject.dives
        ? l10n.rules_condition_everyDive
        : l10n.rules_condition_everySite;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Tooltip(
            message: l10n.rules_reorderTooltip,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ),
        title: Text(rule.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (condition != null)
              Text(condition, style: const TextStyle(fontFamily: 'monospace')),
            for (final a in rule.actions)
              Text(describeRuleAction(l10n, units, a, nameOf)),
            Text(
              ruleTriggersLabel(l10n, rule),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            if (problem != null)
              Text(problem, style: TextStyle(color: theme.colorScheme.error))
            else if (broken)
              Text(
                l10n.rules_problem_brokenAction,
                style: TextStyle(color: theme.colorScheme.tertiary),
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () => context.push('/rules/${rule.id}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: l10n.rules_row_enabled,
              child: Switch(
                value: rule.enabled,
                onChanged: (on) async {
                  try {
                    await ref
                        .read(ruleRepositoryProvider)
                        .setEnabled(rule.id, on);
                  } catch (e, st) {
                    _log.error(
                      'Failed to toggle rule',
                      error: e,
                      stackTrace: st,
                    );
                    if (context.mounted) showRulesError(context);
                  }
                },
              ),
            ),
            RuleRowMenu(rule: rule),
          ],
        ),
      ),
    );
  }
}
