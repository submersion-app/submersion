import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/presentation/formatters/observation_sentence.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The kinds of observation the diver muted, each with Unmute (#2381).
Future<void> showMutedObservationKinds(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const SafeArea(child: _MutedKindsSheet()),
    );

class _MutedKindsSheet extends ConsumerWidget {
  const _MutedKindsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = ref.watch(
      settingsProvider.select((s) => s.insightsMutedObservationRules),
    );
    // A newer build's rule ids stay stored but are not listed here.
    final rules = [
      for (final rule in ObservationRuleId.values)
        if (muted.contains(rule.dbValue)) rule,
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.insights_observations_mutedKinds,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.insights_observations_mutedKinds_empty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final rule in rules)
                    ListTile(
                      title: Text(observationRuleLabel(rule, l10n)),
                      trailing: IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: l10n.insights_observations_unmute,
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .setObservationRuleMuted(rule, false),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
