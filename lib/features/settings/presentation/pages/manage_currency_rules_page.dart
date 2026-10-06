import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/presentation/currency_rule_display.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_currency_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/currency_rule_edit_dialog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/fab_clearance.dart';

/// Settings > Manage > Certification currency (issue #2267): the built-in
/// rule catalog and the diver's own rules. Uses the Manage-page shape: a
/// lower-right extended FAB to add, two icon actions per custom row.
///
/// Built-in rows are read-only reference data that never sync. Tapping one
/// opens a copy-on-write editor: saving creates a custom rule that
/// supersedes it, and the engine then ignores the built-in. Deleting that
/// custom rule brings the built-in back by itself.
class ManageCurrencyRulesPage extends ConsumerWidget {
  const ManageCurrencyRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rulesAsync = ref.watch(currencyRulesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(l10n.currencyRules_title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        tooltip: l10n.currencyRules_addTooltip,
        icon: const Icon(Icons.add),
        label: Text(l10n.currencyRules_addTooltip),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rules) {
          final custom = [
            for (final r in rules)
              if (!r.isBuiltIn) r,
          ]..sort((a, b) => a.name.compareTo(b.name));
          final builtIn =
              [
                for (final r in rules)
                  if (r.isBuiltIn) r,
              ]..sort(
                (a, b) => currencyRuleName(
                  l10n,
                  a,
                ).compareTo(currencyRuleName(l10n, b)),
              );
          final byId = {for (final r in rules) r.id: r};
          final supersededBy = {
            for (final r in custom)
              if (r.supersedesRuleId != null) r.supersedesRuleId!: r,
          };
          return ListView(
            padding: kFabListPadding,
            children: [
              if (custom.isNotEmpty) ...[
                _header(context, l10n.currencyRules_custom),
                for (final rule in custom)
                  _customTile(context, ref, rule, byId[rule.supersedesRuleId]),
                const Divider(),
              ],
              _header(context, l10n.currencyRules_builtIn),
              for (final rule in builtIn)
                _builtInTile(context, ref, rule, supersededBy[rule.id]),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  String _summary(AppLocalizations l10n, CurrencyRule rule) =>
      rule.clockKind == CurrencyClockKind.activity
      ? l10n.currencyRules_summary_activity(rule.lapseDays)
      : l10n.currencyRules_summary_date(rule.lapseDays);

  Widget _builtInTile(
    BuildContext context,
    WidgetRef ref,
    CurrencyRule rule,
    CurrencyRule? replacement,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListTile(
      leading: Icon(
        Icons.event_repeat,
        color: replacement == null
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      ),
      title: Text(currencyRuleName(l10n, rule)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_summary(l10n, rule)),
          if (replacement != null)
            Text(l10n.currencyRules_replacedBy(replacement.name), style: small),
        ],
      ),
      // A replaced built-in opens its replacement, so a second tap never
      // stacks two custom rules over one built-in.
      onTap: () => _edit(context, ref, replacement ?? rule),
    );
  }

  Widget _customTile(
    BuildContext context,
    WidgetRef ref,
    CurrencyRule rule,
    CurrencyRule? replaces,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListTile(
      leading: Icon(
        Icons.edit_calendar_outlined,
        color: theme.colorScheme.secondary,
      ),
      title: Text(rule.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_summary(l10n, rule)),
          if (replaces != null)
            Text(
              l10n.currencyRules_replaces(currencyRuleName(l10n, replaces)),
              style: small,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.currencyRules_editTooltip,
            onPressed: () => _edit(context, ref, rule),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.currencyRules_deleteTooltip,
            onPressed: () => _confirmDelete(context, ref, rule),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CurrencyRule? editing,
  ) async {
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (!context.mounted) return;
    final result = await showCurrencyRuleEditDialog(
      context,
      editing: editing,
      diverId: diverId,
    );
    if (result == null) return;
    final repo = ref.read(certificationCurrencyRepositoryProvider);
    if (result.id.isEmpty) {
      await repo.createRule(result);
    } else {
      await repo.updateRule(result);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CurrencyRule rule,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.currencyRules_deleteDialog_title),
        content: Text(l10n.currencyRules_deleteDialog_content(rule.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(certificationCurrencyRepositoryProvider)
          .deleteRule(rule.id);
    }
  }
}
