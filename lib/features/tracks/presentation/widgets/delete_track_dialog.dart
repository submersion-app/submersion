import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/track_item_location.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

/// Asks before [item] is deleted, in the wording of the track's own
/// feature. True once the diver confirms. Shared by the Tracks list and the
/// tracks' own pages (issue #4527), so a delete reads the same from either.
Future<bool> confirmDeleteTrack(
  BuildContext context,
  TrackListItem item,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => DeleteTrackDialog(item: item),
    ) ==
    true;

/// What the app forgets once [item] is deleted: the map's pick, when it is
/// this track, and the track opened last.
void forgetDeletedTrack(WidgetRef ref, TrackListItem item) {
  final section = mapListSelectionProvider(kTracksSectionKey);
  if (ref.read(section).selectedId == item.selectionKey) {
    ref.read(section.notifier).deselect();
  }
  forgetOpenedTrack(ref, item);
}

/// Confirms a delete in the wording of the track's own feature.
class DeleteTrackDialog extends StatelessWidget {
  const DeleteTrackDialog({super.key, required this.item});

  final TrackListItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, message) = switch (item) {
      GpsTrackItem() => (
        l10n.gpsLogger_deleteTrackTitle,
        l10n.gpsLogger_deleteTrackMessage,
      ),
      UnderwaterTrackItem(:final track) => (
        l10n.navTrack_detail_deleteTrackTitle,
        l10n.navTrack_list_deleteMessage(
          track.name ?? track.sourceRef ?? track.id,
        ),
      ),
    };
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    );
  }
}
