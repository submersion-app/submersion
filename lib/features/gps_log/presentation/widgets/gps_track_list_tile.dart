import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_thumbnail.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_row_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_badge_line.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One row in a list of recorded tracks: thumbnail, title, figures.
///
/// Both surfaces that list tracks (the GPS log page and the overview map's
/// list pane) build their rows here, so they cannot drift apart again.
/// Callers key each tile by track id: a recycled unkeyed row keeps the
/// previous track's thumbnail camera.
class GpsTrackListTile extends ConsumerWidget {
  const GpsTrackListTile({
    super.key,
    required this.track,
    required this.onTap,
    this.selected = false,
    this.onDelete,
    this.contentPadding,
    this.kindBadge,
  });

  final GpsTrack track;
  final VoidCallback onTap;
  final bool selected;

  /// Shown as a trailing delete icon when set.
  final VoidCallback? onDelete;
  final EdgeInsetsGeometry? contentPadding;

  /// Shown at the end of the detail line, the same place an
  /// underwater row puts its badge (next to its dive link), so both kinds
  /// of row in the mixed Tracks list carry it on their last line.
  final Widget? kindBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    return ListTile(
      onTap: onTap,
      selected: selected,
      contentPadding: contentPadding,
      minLeadingWidth: kTrackThumbnailWidth,
      leading: GpsTrackThumbnail(trackId: track.id),
      title: Text(formatTrackTitle(units, track)),
      subtitle: TrackBadgeLine(
        badge: kindBadge,
        child: Text(formatTrackDetailLine(l10n, units, track)),
      ),
      trailing: onDelete == null
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.common_action_delete,
              onPressed: onDelete,
            ),
    );
  }
}
