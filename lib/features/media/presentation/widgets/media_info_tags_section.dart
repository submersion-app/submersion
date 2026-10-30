import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/media_tag_navigation.dart';
import 'package:submersion/features/media/presentation/widgets/media_tag_sheet.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The info panel's Tags card (issue #1970): the photo's tags as colored
/// chips, each opening the library filtered to it, and Edit tags. Shown
/// even with no tags, so the panel is a way in to tagging on every width.
class MediaInfoTagsSection extends ConsumerWidget {
  const MediaInfoTagsSection({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tags =
        ref
            .watch(
              tagsForItemProvider((scope: TagScope.media, itemId: item.id)),
            )
            .value ??
        const <Tag>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.media_info_tags, style: theme.textTheme.titleMedium),
            const Divider(),
            if (tags.isEmpty)
              Text(
                l10n.media_info_noTags,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    TagChip(
                      tag: tag,
                      tooltip: l10n.media_info_showWithTag(tag.name),
                      onTap: () => openMediaWithTag(context, ref, tag.id),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('media_info_editTags'),
                icon: const Icon(Icons.label_outline, size: 18),
                label: Text(l10n.tags_action_edit),
                onPressed: () => showMediaTagSheet(context, item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
