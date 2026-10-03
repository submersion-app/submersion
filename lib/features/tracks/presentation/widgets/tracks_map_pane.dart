import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/gps_log/presentation/widgets/gps_track_empty_map.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_info_card.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_info_card.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/domain/tracks_query.dart';
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
    final truncated = ref.watch(tracksOverviewTruncatedProvider);
    final selectedKey = ref
        .watch(mapListSelectionProvider(kTracksSectionKey))
        .selectedId;
    return switch (overviewAsync) {
      AsyncLoading() when overview.isEmpty => const Center(
        child: CircularProgressIndicator(),
      ),
      // Only before any data: a refresh that fails keeps the tracks the list
      // beside it still shows.
      AsyncError() when !overviewAsync.hasValue => Center(
        child: Text(l10n.common_error_tryAgain),
      ),
      // Tracks exist but none can be placed: say so rather than "no tracks".
      _ when overview.isEmpty => GpsTrackEmptyMap(
        message: listed.isEmpty
            ? l10n.gpsTrack_map_noTracks
            : l10n.tracks_map_noMappable,
      ),
      _ => Stack(
        children: [
          TracksOverviewMap(
            items: withSelectedTrack(overview, listed, selectedKey),
            selectedKey: selectedKey,
            controller: controller,
          ),
          // The cap limits this map alone (the list shows every track), so
          // the notice says so here, where it is true.
          if (truncated)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _CapNotice(
                text: l10n.gpsTrack_map_truncated(kTracksOverviewLimit),
              ),
            ),
        ],
      ),
    };
  }
}

/// [overview] plus the selected track when the cap left it out, so a row
/// picked from further down the list is still drawn and framed. One extra
/// blob at most, so the cap's cost bound holds.
List<TrackListItem> withSelectedTrack(
  List<TrackListItem> overview,
  List<TrackListItem> listed,
  String? selectedKey,
) {
  if (selectedKey == null) return overview;
  if (overview.any((item) => item.selectionKey == selectedKey)) {
    return overview;
  }
  final selected = listed
      .where((item) => item.selectionKey == selectedKey && item.isMappable)
      .firstOrNull;
  return selected == null
      ? overview
      : List.unmodifiable([...overview, selected]);
}

class _CapNotice extends StatelessWidget {
  const _CapNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('tracks-truncated-notice'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(text, style: theme.textTheme.bodySmall),
      ),
    );
  }
}

/// The info card for the selected track, or nothing when no listed track
/// is selected (including a selection the filters now hide).
///
/// A widget of its own so a track change rebuilds this card, not the whole
/// page that hosts it.
class TracksInfoCard extends ConsumerWidget {
  const TracksInfoCard({super.key, required this.onOpen});

  final ValueChanged<TrackListItem> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(tracksListProvider).value ?? const <TrackListItem>[];
    final section = mapListSelectionProvider(kTracksSectionKey);
    final selectedKey = ref.watch(section).selectedId;
    final selected = items
        .where((item) => item.selectionKey == selectedKey)
        .firstOrNull;
    if (selected == null) return const SizedBox.shrink();
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
}
