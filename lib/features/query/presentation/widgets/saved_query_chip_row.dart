import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "Saved" chip row of spec Unit 7: one chip per saved query of
/// [subject]; tapping a readable one applies it. A query with a deleted
/// reference applies flagged; one this build cannot read is marked and
/// explains itself on tap. Renders nothing when there is nothing saved.
class SavedQueryChipRow extends ConsumerWidget {
  const SavedQueryChipRow({
    super.key,
    required this.subject,
    required this.onApply,
  });

  final QuerySubject subject;
  final ValueChanged<SavedQueryLoad> onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loads = ref.watch(savedQueryLoadsProvider(subject.name)).value;
    if (loads == null || loads.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.query_savedRow_title,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [for (final l in loads) _chip(context, l, theme)],
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, SavedQueryLoad load, ThemeData theme) {
    final name = load.saved.name;
    switch (load.problem) {
      case null:
        return ActionChip(
          avatar: const Icon(Icons.bookmark_outline, size: 16),
          label: Text(name),
          onPressed: () => onApply(load),
        );
      case SavedQueryProblem.unresolvedRef:
        return Tooltip(
          message: context.l10n.query_savedRow_unresolved(name),
          child: ActionChip(
            avatar: Icon(
              Icons.warning_amber,
              size: 16,
              color: theme.colorScheme.tertiary,
            ),
            label: Text(name),
            onPressed: () => onApply(load),
          ),
        );
      case SavedQueryProblem.unreadable:
      case SavedQueryProblem.invalid:
      case SavedQueryProblem.unknownSubject:
        return ActionChip(
          avatar: Icon(
            Icons.error_outline,
            size: 16,
            color: theme.colorScheme.error,
          ),
          label: Text(name),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.query_savedRow_unreadable(name, load.detail ?? ''),
              ),
            ),
          ),
        );
    }
  }
}
