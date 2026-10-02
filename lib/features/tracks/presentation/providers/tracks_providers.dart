import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/domain/tracks_query.dart';
import 'package:submersion/features/tracks/domain/tracks_summary.dart';

/// The Tracks page's kind filter. Lives as long as the app, like the date
/// filter it sits beside, so the map page and the list agree.
final trackKindFilterProvider = StateProvider<TrackKindFilter>(
  (ref) => TrackKindFilter.all,
);

/// GPS and underwater tracks as one filtered list, newest first.
///
/// `allNavTracksProvider` reads without points, so no row decodes a blob to
/// appear here.
final tracksListProvider = FutureProvider<List<TrackListItem>>((ref) async {
  final kind = ref.watch(trackKindFilterProvider);
  final range = ref.watch(trackDateFilterProvider);
  final gps = await ref.watch(gpsTracksProvider.future);
  final underwater = await ref.watch(allNavTracksProvider.future);
  return mergeTracks(
    gps: gps,
    underwater: underwater,
    kind: kind,
    range: range,
  );
});

/// What the overview map draws; see [capOverview].
final tracksOverviewProvider = FutureProvider<List<TrackListItem>>((ref) async {
  final items = await ref.watch(tracksListProvider.future);
  return capOverview(items).items;
});

/// True when the overview cap dropped mappable tracks the filters allowed.
final tracksOverviewTruncatedProvider = Provider<bool>((ref) {
  final items = ref.watch(tracksListProvider).value ?? const <TrackListItem>[];
  return capOverview(items).truncated;
});

/// The summary strip's figures, following the active filters.
final tracksSummaryProvider = FutureProvider<TracksSummary>((ref) async {
  final items = await ref.watch(tracksListProvider.future);
  final dives = await ref.watch(divesProvider.future);
  return summarizeTracks(items, dives);
});
