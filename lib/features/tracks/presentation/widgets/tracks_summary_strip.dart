import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/gps_log/presentation/widgets/track_row_labels.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_stat_tile.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Tracks, recorded time and dives covered for what the filters show.
///
/// Placeholders rather than zeros while the figures load, so a cold open
/// never flashes "0 tracks" over a full library.
class TracksSummaryStrip extends ConsumerWidget {
  const TracksSummaryStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(tracksSummaryProvider).value;
    final tiles = <(String, String)>[
      (l10n.gpsLogger_summary_tracks, summary?.trackCount.toString() ?? '--'),
      (
        l10n.gpsLogger_summary_recordedTime,
        summary == null ? '--' : formatCompactDuration(summary.recordedTime),
      ),
      (
        l10n.gpsLogger_summary_divesCovered,
        summary?.divesCovered.toString() ?? '--',
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            for (final (label, value) in tiles)
              Expanded(
                child: TrackStatTile(label: label, value: value),
              ),
          ],
        ),
      ),
    );
  }
}
