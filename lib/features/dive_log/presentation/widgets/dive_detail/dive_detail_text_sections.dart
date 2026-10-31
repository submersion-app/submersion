import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/tags/presentation/tag_dives_navigation.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

/// The Tags card.
class DiveTagsSection extends ConsumerWidget {
  const DiveTagsSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.diveLog_detail_section_tags,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  context.l10n.diveLog_detail_tagCount(dive.tags.length),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dive.tags
                  .map(
                    (tag) => TagChip(
                      tag: tag,
                      tooltip: context.l10n.tags_action_showDives(tag.name),
                      onTap: () => openDivesWithTag(context, ref, tag.id),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Notes card.
class DiveNotesSection extends StatelessWidget {
  const DiveNotesSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_detail_section_notes,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            if (dive.notes.isNotEmpty)
              MarkdownNotesView(dive.notes)
            else
              Text(
                context.l10n.diveLog_detail_noNotes,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The Custom fields card.
class DiveCustomFieldsSection extends StatelessWidget {
  const DiveCustomFieldsSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.diveLog_detail_section_customFields,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  context.l10n.diveLog_detail_customFieldCount(
                    dive.customFields.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...dive.customFields.map(
              (field) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${field.key}:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        field.value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
