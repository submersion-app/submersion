import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_date_filter_action.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_empty_map.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_overview_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';

/// Every recorded track on one map, bound to a list pane on desktop.
///
/// At desktop width the GPS log page hosts this same split itself; this route
/// stays for phones, where the log is a single column, and for deep links.
class GpsTrackMapPage extends ConsumerStatefulWidget {
  const GpsTrackMapPage({super.key});

  @override
  ConsumerState<GpsTrackMapPage> createState() => _GpsTrackMapPageState();
}

class _GpsTrackMapPageState extends ConsumerState<GpsTrackMapPage> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Capped: every track drawn here hydrates a full point blob and, on a cold
    // cache, spawns its own simplification isolate.
    final tracksAsync = ref.watch(overviewTracksProvider);
    final tracks = tracksAsync.value ?? const <GpsTrack>[];
    final truncated = ref.watch(overviewTracksTruncatedProvider);
    final selection = ref.watch(mapListSelectionProvider(kGpsTrackSectionKey));

    return MapListScaffold(
      sectionKey: kGpsTrackSectionKey,
      title: l10n.gpsTrack_map_title,
      onBackPressed: () => context.go('/gps-log'),
      actions: const [GpsTrackDateFilterAction()],
      listPane: _TrackListPane(
        tracks: tracks,
        selectedId: selection.selectedId,
        truncatedNotice: truncated
            ? l10n.gpsTrack_map_truncated(kOverviewTrackLimit)
            : null,
      ),
      // Distinguish "still loading" from "genuinely none": reading
      // `value ?? []` as authoritative flashed "No recorded tracks" on every
      // cold open and after every filter change, and showed the same message
      // when the query had actually failed.
      mapPane: switch (tracksAsync) {
        AsyncLoading() when tracks.isEmpty => const Center(
          child: CircularProgressIndicator(),
        ),
        AsyncError() => Center(child: Text(l10n.common_error_tryAgain)),
        _ when tracks.isEmpty => GpsTrackEmptyMap(
          message: l10n.gpsTrack_map_noTracks,
        ),
        _ => GpsTrackOverviewMap(
          tracks: tracks,
          selectedId: selection.selectedId,
          controller: _mapController,
        ),
      },
    );
  }
}

class _TrackListPane extends ConsumerWidget {
  const _TrackListPane({
    required this.tracks,
    required this.selectedId,
    this.truncatedNotice,
  });

  final List<GpsTrack> tracks;
  final String? selectedId;

  /// Set when the cap dropped tracks the date filter allowed.
  final String? truncatedNotice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = truncatedNotice;
    return ListView.builder(
      // The notice occupies index 0 so it scrolls with the rows rather than
      // stealing height from a narrow list pane.
      itemCount: tracks.length + (notice == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (notice != null) {
          if (index == 0) {
            return Padding(
              key: const ValueKey('gps-track-truncated-notice'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                notice,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          index -= 1;
        }
        final track = tracks[index];
        return GpsTrackListTile(
          key: ValueKey(track.id),
          track: track,
          selected: track.id == selectedId,
          onTap: () => ref
              .read(mapListSelectionProvider(kGpsTrackSectionKey).notifier)
              .select(track.id),
        );
      },
    );
  }
}
