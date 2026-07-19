import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/start_session_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dive-detail section for the linked pre-dive checklist session. Always
/// renders: with a session it is the audit-record card, without one it is
/// the affordance for linking (logged dives) or running (planned dives).
class DivePreDiveSection extends ConsumerWidget {
  final Dive dive;

  const DivePreDiveSection({super.key, required this.dive});

  Future<void> _showLinkPicker(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final repository = ref.read(preDiveSessionRepositoryProvider);
    final candidates = await repository.getUnlinkedSessions(
      diverId: dive.diverId,
    );
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.preDive_section_noUnlinked)));
      return;
    }
    final chosen = await showDialog<PreDiveSession>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.preDive_section_link),
        children: [
          for (final session in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(session),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(session.templateName),
                subtitle: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(session.startedAt),
                ),
              ),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await repository.linkToDive(chosen.id, dive.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(preDiveSessionForDiveProvider(dive.id)).value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.preDive_section_title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (session != null)
              _LinkedSessionRow(session: session, dive: dive)
            else if (dive.isPlanned)
              OutlinedButton.icon(
                icon: const Icon(Icons.fact_check),
                label: Text(l10n.preDive_section_run),
                onPressed: () =>
                    showStartSessionSheet(context, diveId: dive.id),
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.link),
                label: Text(l10n.preDive_section_link),
                onPressed: () => _showLinkPicker(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinkedSessionRow extends ConsumerWidget {
  final PreDiveSession session;
  final Dive dive;

  const _LinkedSessionRow({required this.session, required this.dive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = ref.watch(preDiveSessionItemsProvider(session.id)).value;
    final flagged = items == null
        ? 0
        : ChecklistSessionEngine.flaggedCount(items);
    final when = session.completedAt ?? session.startedAt;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        flagged > 0 ? Icons.flag : Icons.check_circle_outline,
        color: flagged > 0
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
      ),
      title: Text(session.templateName),
      subtitle: Text(
        [
          MaterialLocalizations.of(context).formatMediumDate(when),
          TimeOfDay.fromDateTime(when).format(context),
          if (flagged > 0) l10n.preDive_runner_flaggedBadge(flagged),
        ].join(' - '),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'unlink') {
            ref
                .read(preDiveSessionRepositoryProvider)
                .unlinkFromDive(session.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'unlink',
            child: Text(l10n.preDive_section_unlink),
          ),
        ],
      ),
      onTap: () => context.push('/pre-dive-sessions/${session.id}'),
    );
  }
}
