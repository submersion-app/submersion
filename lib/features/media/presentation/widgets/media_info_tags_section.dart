import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/media_tag_navigation.dart';
import 'package:submersion/features/media/presentation/widgets/media_tag_sheet.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The info panel's Tags card (issue #1970): the photo's tags as colored
/// chips, each opening the library filtered to it, and Edit tags. Shown
/// even with no tags, so the panel is a way in to tagging on every width.
class MediaInfoTagsSection extends ConsumerWidget {
  const MediaInfoTagsSection({
    super.key,
    required this.item,
    this.readOnly = false,
    this.sitting,
  });

  final MediaItem item;

  /// No Edit tags: the photo is locked, or shown where it has no lock of its
  /// own (issue #4527).
  final bool readOnly;

  /// The photo's sitting: its held tags are shown, and Edit tags holds.
  final EditSession<PhotoRecord>? sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The info sheet is a route of its own, which the viewer's redraws do
    // not reach: the card follows the sitting itself.
    final session = sitting;
    if (session == null || session.isDisposed) return _card(context, ref);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _card(context, ref),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final held = sittingIsOver(sitting, item.id) ? sitting : null;
    // Edit tags holds its change in the sitting, so it is offered only while
    // one is over this photo: not locked, nor once the sitting has ended.
    final canEdit = !readOnly && held != null;
    final tags = held != null
        ? held.working.tags
        : ref
                  .watch(
                    tagsForItemProvider((
                      scope: TagScope.media,
                      itemId: item.id,
                    )),
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
            if (canEdit) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('media_info_editTags'),
                  icon: const Icon(Icons.label_outline, size: 18),
                  label: Text(l10n.tags_action_edit),
                  onPressed: () =>
                      showMediaTagSheet(context, item, sitting: held),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
