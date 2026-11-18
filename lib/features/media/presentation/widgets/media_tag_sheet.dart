import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/scoped_tags_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Opens the tag sheet for [item] (issue #1970), the same modal shape as the
/// species and info sheets.
///
/// The sheet changes nothing itself: the tags chosen are held in [sitting]
/// until it is saved (issue #4527).
Future<void> showMediaTagSheet(
  BuildContext context,
  MediaItem item, {
  required EditSession<PhotoRecord> sitting,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  // A modal sheet does not make room for the keyboard by itself; without
  // this the tag field and its Create suggestion sit under it (#4406).
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => MediaTagSheet(
        item: item,
        scrollController: controller,
        sitting: sitting,
      ),
    ),
  ),
);

/// Tag a photo or video. The tags are held in the photo's sitting until the
/// viewer's Save (issue #4527), and once it has ended the sheet only reads.
class MediaTagSheet extends ConsumerWidget {
  const MediaTagSheet({
    super.key,
    required this.item,
    this.scrollController,
    required this.sitting,
  });

  final MediaItem item;
  final ScrollController? scrollController;

  /// The photo's sitting, which holds the tags chosen.
  final EditSession<PhotoRecord> sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sitting.isDisposed) return _sheet(context, ref);
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => _sheet(context, ref),
    );
  }

  Widget _sheet(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = (scope: TagScope.media, itemId: item.id);
    // Shown once the sitting has ended, when the sheet only reads.
    final stored = ref.watch(tagsForItemProvider(key));
    // A sitting that has ended takes nothing: a change then would be made
    // outside the photo's lock.
    final ended = sitting.isDisposed;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        ScopedTagsField(
          scope: TagScope.media,
          label: l10n.media_info_tags,
          browseKey: const ValueKey('media_tags_browse'),
          selectedTags: ended ? stored.value ?? const [] : sitting.working.tags,
          enabled: !ended,
          onTagsChanged: _hold,
        ),
      ],
    );
  }

  /// Holds [tags] as the photo's tags in the sitting.
  void _hold(List<Tag> tags) {
    if (sitting.isDisposed || sitting.isFrozen) return;
    sitting.set(
      photoTagsField,
      MediaTagEdits.between(sitting.stored.tags, tags),
    );
  }
}
