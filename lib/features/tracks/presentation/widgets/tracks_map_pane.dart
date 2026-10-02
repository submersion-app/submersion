import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/gps_log/presentation/widgets/gps_track_empty_map.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_info_card.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_info_card.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

/// The map side of the Tracks split and the phone map page.
///
/// A loading library must not flash the empty message, and a failed query
/// must not claim there are no tracks.
class TracksMapPane extends ConsumerWidget {
  const TracksMapPane({super.key, required this.controller});

  final MapController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overviewAsync = ref.watch(tracksOverviewProvider);
    final overview = overviewAsync.value ?? const <TrackListItem>[];
    final listed =
        ref.watch(tracksListProvider).value ?? const <TrackListItem>[];
    final selection = ref.watch(mapListSelectionProvider(kTracksSectionKey));
    return switch (overviewAsync) {
      AsyncLoading() when overview.isEmpty => const Center(
        child: CircularProgressIndicator(),
      ),
      AsyncError() => Center(child: Text(l10n.common_error_tryAgain)),
      // Tracks exist but none can be placed: say so rather than "no tracks".
      _ when overview.isEmpty => GpsTrackEmptyMap(
        message: listed.isEmpty
            ? l10n.gpsTrack_map_noTracks
            : l10n.tracks_map_noMappable,
      ),
      _ => TracksOverviewMap(
        items: overview,
        selectedKey: selection.selectedId,
        controller: controller,
      ),
    };
  }
}

/// The info card for the selected track, or null when nothing listed is
/// selected (including a selection the filters now hide). Call from build.
Widget? tracksInfoCard({
  required WidgetRef ref,
  required ValueChanged<TrackListItem> onOpen,
}) {
  final items = ref.watch(tracksListProvider).value ?? const <TrackListItem>[];
  final section = mapListSelectionProvider(kTracksSectionKey);
  final selectedKey = ref.watch(section).selectedId;
  final selected = items
      .where((item) => item.selectionKey == selectedKey)
      .firstOrNull;
  if (selected == null) return null;
  void close() => ref.read(section.notifier).deselect();
  return switch (selected) {
    GpsTrackItem(:final track) => GpsTrackInfoCard(
      track: track,
      onDetailsTap: () => onOpen(selected),
      onClose: close,
    ),
    UnderwaterTrackItem(:final track) => NavTrackInfoCard(
      route: track,
      onDetailsTap: () => onOpen(selected),
      onClose: close,
    ),
  };
}
