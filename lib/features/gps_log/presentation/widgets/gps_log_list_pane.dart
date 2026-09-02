import 'package:flutter/material.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_log_empty_state.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_log_summary_strip.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Match dives to GPS logs": sweeps GPS-less dives against every track.
class GpsLogMatchButton extends StatelessWidget {
  const GpsLogMatchButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.add_location_alt_outlined),
      label: Text(context.l10n.gpsLogger_matchButton),
      onPressed: onPressed,
    );
  }
}

/// The list side of the GPS log's desktop split: summary, actions, rows.
///
/// A row tap selects the track on the map rather than opening it; the map's
/// info card carries the open action, as on the site map.
class GpsLogListPane extends StatelessWidget {
  const GpsLogListPane({
    super.key,
    required this.tracks,
    required this.selectedId,
    required this.onMatch,
    required this.onSelect,
    required this.onDelete,
    this.leading,
    this.truncatedNotice,
  });

  final List<GpsTrack> tracks;
  final String? selectedId;
  final VoidCallback onMatch;
  final ValueChanged<String> onSelect;
  final ValueChanged<GpsTrack> onDelete;

  /// Rendered above the summary: the record card on a tablet wide enough
  /// for the split, which can still go on the boat.
  final Widget? leading;

  /// Set when the overview cap dropped tracks the date filter allowed.
  final String? truncatedNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = truncatedNotice;
    return ListView.builder(
      // The header occupies index 0 so it scrolls with the rows rather than
      // stealing height from the pane.
      itemCount: tracks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leading != null) ...[leading!, const SizedBox(height: 16)],
                const GpsLogSummaryStrip(),
                const SizedBox(height: 12),
                GpsLogMatchButton(onPressed: onMatch),
                if (notice != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    notice,
                    key: const ValueKey('gps-track-truncated-notice'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (tracks.isEmpty) const GpsLogEmptyState(),
              ],
            ),
          );
        }
        final track = tracks[index - 1];
        return GpsTrackListTile(
          key: ValueKey(track.id),
          track: track,
          selected: track.id == selectedId,
          onTap: () => onSelect(track.id),
          onDelete: () => onDelete(track),
        );
      },
    );
  }
}
