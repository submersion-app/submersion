import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dashboard card for pre-dive checklists. Hidden until the feature has
/// been used (a session exists or a user template was created) so
/// non-users pay no UI tax; built-ins alone do not surface it.
class PreDiveDashboardCard extends ConsumerWidget {
  const PreDiveDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final active = ref.watch(preDiveActiveSessionProvider).value;
    final sessions = ref.watch(preDiveSessionsProvider).value ?? const [];
    final templates = ref.watch(preDiveTemplatesProvider).value ?? const [];
    final hasUserTemplates = templates.any((t) => !t.isBuiltIn);

    if (active == null && sessions.isEmpty && !hasUserTemplates) {
      return const SizedBox.shrink();
    }

    final Widget action;
    if (active != null) {
      final items = ref.watch(preDiveSessionItemsProvider(active.id)).value;
      final resolved = items == null
          ? 0
          : ChecklistSessionEngine.resolvedCount(items);
      action = FilledButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: Text(
          l10n.preDive_dashboard_resume(resolved, items?.length ?? 0),
        ),
        onPressed: () => context.push('/pre-dive-sessions/${active.id}'),
      );
    } else {
      action = FilledButton.tonalIcon(
        icon: const Icon(Icons.fact_check),
        label: Text(l10n.preDive_dashboard_start),
        onPressed: () => context.push('/pre-dive-sessions'),
      );
    }

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.preDive_dashboard_title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: action),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
