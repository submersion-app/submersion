import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
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
/// With a [sitting] the sheet changes nothing: the tags chosen are held in
/// it until it is saved (issue #4527).
Future<void> showMediaTagSheet(
  BuildContext context,
  MediaItem item, {
  EditSession<PhotoRecord>? sitting,
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

/// Tag a photo or video. Every change is saved as it is made, as species
/// tags are: the sheet has no Save button to forget.
class MediaTagSheet extends ConsumerWidget {
  const MediaTagSheet({
    super.key,
    required this.item,
    this.scrollController,
    this.sitting,
  });

  final MediaItem item;
  final ScrollController? scrollController;

  /// The photo's sitting; null saves each change at once, as before.
  final EditSession<PhotoRecord>? sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = sitting;
    if (session == null || session.isDisposed) {
      return _sheet(context, ref, session);
    }
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _sheet(context, ref, session),
    );
  }

  Widget _sheet(
    BuildContext context,
    WidgetRef ref,
    EditSession<PhotoRecord>? session,
  ) {
    final l10n = context.l10n;
    final key = (scope: TagScope.media, itemId: item.id);
    final stored = ref.watch(tagsForItemProvider(key));
    final held = session != null && !session.isDisposed ? session : null;
    // A sitting that has ended takes nothing, and does not fall back to
    // writing at once either: that would change the photo outside its lock.
    final ended = session != null && held == null;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        ScopedTagsField(
          scope: TagScope.media,
          label: l10n.media_info_tags,
          browseKey: const ValueKey('media_tags_browse'),
          selectedTags: held?.working.tags ?? stored.value ?? const [],
          // Editing before the stored tags load would save a set built
          // without them, dropping them. A sitting holds them already.
          enabled: !ended && (held != null || stored.hasValue),
          onTagsChanged: (tags) => session == null
              ? _save(context, ref, tags)
              : _hold(session, tags),
        ),
      ],
    );
  }

  /// Holds [tags] as the photo's tags in [session].
  void _hold(EditSession<PhotoRecord> session, List<Tag> tags) {
    if (session.isDisposed || session.isFrozen) return;
    session.set(
      photoTagsField,
      MediaTagEdits.between(session.stored.tags, tags),
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
