import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/scoped_tags_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the tag sheet for [item] (issue #1970), the same modal shape as the
/// species and info sheets.
Future<void> showMediaTagSheet(BuildContext context, MediaItem item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) =>
            MediaTagSheet(item: item, scrollController: controller),
      ),
    );

/// Tag a photo or video. Every change is saved as it is made, as species
/// tags are: the sheet has no Save button to forget.
class MediaTagSheet extends ConsumerWidget {
  const MediaTagSheet({super.key, required this.item, this.scrollController});

  final MediaItem item;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = (scope: TagScope.media, itemId: item.id);
    final stored = ref.watch(tagsForItemProvider(key));

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        ScopedTagsField(
          scope: TagScope.media,
          label: l10n.media_info_tags,
          browseKey: const ValueKey('media_tags_browse'),
          selectedTags: stored.value ?? const [],
          // Editing before the stored tags load would save a set built
          // without them, dropping them.
          enabled: stored.hasValue,
          onTagsChanged: (tags) => _save(context, ref, tags),
        ),
      ],
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    List<Tag> tags,
  ) async {
    try {
      await ref.read(tagLinkRepositoryProvider(TagScope.media)).replaceTags(
        item.id,
        [for (final t in tags) t.id],
      );
    } catch (e, stackTrace) {
      LoggerService.forClass(MediaTagSheet).error(
        'Failed to tag media ${item.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.common_error_tryAgain)),
      );
    }
  }
}
