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
  // Both watched before either is awaited, so the two queries overlap.
  // Future.wait observes both and rethrows the first error as it was thrown
  // (a record's .wait would wrap it in a ParallelWaitError).
  final gpsFuture = ref.watch(gpsTracksProvider.future);
  final underwaterFuture = ref.watch(allNavTracksProvider.future);
  await Future.wait<Object>([gpsFuture, underwaterFuture]);
  final gps = await gpsFuture;
  final underwater = await underwaterFuture;
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
  final itemsFuture = ref.watch(tracksListProvider.future);
  final divesFuture = ref.watch(divesProvider.future);
  await Future.wait<Object>([itemsFuture, divesFuture]);
  final items = await itemsFuture;
  final dives = await divesFuture;
  return summarizeTracks(items, dives);
});
