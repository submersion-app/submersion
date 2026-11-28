import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/widgets/gear_checklist.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Opens the gear sheet for [item] (issue #5046), the same modal shape as
/// the tag sheet. The sheet changes nothing itself: the gear chosen is held
/// in [sitting] until it is saved.
Future<void> showMediaGearSheet(
  BuildContext context,
  MediaItem item, {
  required EditSession<PhotoRecord> sitting,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  // Room for the keyboard under the search field (#4406).
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => MediaGearSheet(
        item: item,
        scrollController: controller,
        sitting: sitting,
      ),
    ),
  ),
);

/// Link gear to a photo or video: the gear used on its dive first, then the
/// rest of the diver's gear by type. Held in the photo's sitting until the
/// viewer's Save; once the sitting has ended the sheet only reads.
class MediaGearSheet extends ConsumerStatefulWidget {
  const MediaGearSheet({
    super.key,
    required this.item,
    this.scrollController,
    required this.sitting,
  });

  final MediaItem item;
  final ScrollController? scrollController;

  /// The photo's sitting, which holds the gear chosen.
  final EditSession<PhotoRecord> sitting;

  @override
  ConsumerState<MediaGearSheet> createState() => _MediaGearSheetState();
}

class _MediaGearSheetState extends ConsumerState<MediaGearSheet> {
  @override
  Widget build(BuildContext context) {
    final sitting = widget.sitting;
    if (sitting.isDisposed) return _sheet(context);
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => _sheet(context),
    );
  }

  Widget _sheet(BuildContext context) {
    final sitting = widget.sitting;
    final ended = sitting.isDisposed;
    final chosen = ended
        ? (ref.watch(gearIdsForMediaProvider(widget.item.id)).value ??
                  const <String>[])
              .toSet()
        : sitting.working.gearIds.toSet();
    final diveId = widget.item.diveId;
    final onDive = diveId == null
        ? const <String>{}
        : ref.watch(gearOnDiveProvider(diveId)).value ?? const <String>{};
    return GearChecklist(
      title: context.l10n.media_gearSheet_title,
      chosen: chosen,
      firstIds: onDive,
      scrollController: widget.scrollController,
      onToggle: ended ? null : _toggle,
    );
  }

  /// Holds [id] linked or unlinked in the sitting.
  void _toggle(String id) {
    final sitting = widget.sitting;
    if (sitting.isDisposed || sitting.isFrozen) return;
    final current = sitting.working.gearIds;
    final next = current.contains(id)
        ? [
            for (final g in current)
              if (g != id) g,
          ]
        : [...current, id];
    sitting.set(
      photoGearField,
      MediaGearEdits.between(sitting.stored.gearIds, next),
    );
  }
}
