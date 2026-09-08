import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Home card for both kinds of checklist the app keeps, each under its own
/// label and going to its own place.
///
/// The app has two unrelated checklist features: pre-dive runs (timed,
/// immutable audit records) and trip checklists (dated to-dos on a trip).
/// Home used to offer only the pre-dive button, so a diver who kept trip
/// checklists followed the home button and arrived at a page headed
/// "Pre-Dive Checklists" that knew nothing about their list. Naming the two
/// rows separately is the fix: the card no longer implies that the pre-dive
/// runner is where every checklist lives.
///
/// Each row is hidden until it has something to say -- pre-dive until the
/// feature has been used (a session exists or a user template was created;
/// built-ins alone do not surface it), the trip row until the current or next
/// trip actually has items -- and the card itself disappears when neither
/// does, so non-users pay no UI tax.
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
    final tripChecklist = ref.watch(homeTripChecklistProvider).value;

    final showPreDive =
        active != null || sessions.isNotEmpty || hasUserTemplates;
    if (!showPreDive && tripChecklist == null) {
      return const SizedBox.shrink();
    }

    final Widget preDiveAction;
    if (active != null) {
      final items = ref.watch(preDiveSessionItemsProvider(active.id)).value;
      final resolved = items == null
          ? 0
          : ChecklistSessionEngine.resolvedCount(items);
      preDiveAction = FilledButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: Text(
          l10n.preDive_dashboard_resume(resolved, items?.length ?? 0),
        ),
        onPressed: () => context.push('/pre-dive-sessions/${active.id}'),
      );
    } else {
      preDiveAction = FilledButton.tonalIcon(
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
                  l10n.dashboard_checklists_title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showPreDive) ...[
                  const SizedBox(height: 8),
                  _RowLabel(text: l10n.dashboard_checklists_preDiveLabel),
                  const SizedBox(height: 4),
                  SizedBox(width: double.infinity, child: preDiveAction),
                ],
                if (tripChecklist != null) ...[
                  const SizedBox(height: 12),
                  _RowLabel(
                    text: l10n.dashboard_checklists_tripLabel(
                      tripChecklist.trip.name,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.checklist),
                      label: Text(
                        l10n.checklists_progress(
                          tripChecklist.done,
                          tripChecklist.total,
                        ),
                      ),
                      onPressed: () =>
                          context.push('/trips/${tripChecklist.trip.id}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RowLabel extends StatelessWidget {
  final String text;

  const _RowLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
