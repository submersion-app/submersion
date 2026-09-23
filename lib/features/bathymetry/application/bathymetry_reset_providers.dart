import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/screen_awake.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';

/// Deletes every cached swissBATHY3D row: the tile cache AND this source's
/// rows in the outer, quantized [BathymetryCache] together. Deleting only
/// one of the two tables has no visible effect, since the other would keep
/// serving its already-resolved answer (see [BathymetryRepository]'s doc).
/// A no-op wherever the local cache database is not initialized.
final swissBathyClearProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final tileCache = ref.read(swissBathyTileCacheRepositoryProvider);
    final repo = ref.read(bathymetryRepositoryProvider);
    await tileCache?.clearAll();
    await repo?.clearBySource(SwissBathy3dSource.sourceId);
    _invalidateAfterCacheChange(ref);
  };
});

/// Deletes every cached bathymetry row NOT attributed to swissBATHY3D
/// (EMODnet, NOAA DEM, GMRT, ETOPO, and any row with no source at all). A
/// no-op wherever the local cache database is not initialized.
final bathymetryOtherSourcesClearProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    final repo = ref.read(bathymetryRepositoryProvider);
    await repo?.clearAllExceptSource(SwissBathy3dSource.sourceId);
    _invalidateAfterCacheChange(ref);
  };
});

/// Both providers above delete rows out from under two other providers that
/// never learn about it on their own:
///
/// - [mapReloadEstimateProvider] would otherwise keep showing the size it
///   computed from data that is now gone, the next time the reload dialog
///   opens in the same session.
/// - [bathymetryGridProvider], for any cell a diver already has a dive
///   site's 3D view open on, would otherwise keep serving its last-resolved
///   grid from memory even though the row it came from was just deleted --
///   directly undermining a page whose whole purpose is to force a refresh.
///
/// Invalidating the family as a whole (no specific cell) drops every
/// currently-watched instance; anything not currently watched has nothing to
/// invalidate anyway. Found missing by code review.
void _invalidateAfterCacheChange(Ref ref) {
  ref.invalidate(mapReloadEstimateProvider);
  ref.invalidate(bathymetryGridProvider);
}

/// Ensures every known dive site's own swissBATHY3D tile is warm, grouped
/// by lake and awaited -- see [SwissBathy3dSource.warmKnownSites]'s own doc
/// (`swissbathy3d_lake_warm.dart`) for why the reload action cannot rely on
/// [SwissBathy3dSource.fetch]'s fire-and-forget sibling precache to keep up
/// with its own fast, sequential per-site loop. `isCancelled` is checked
/// between lakes, same caveat as [MapReloadNotifier.cancel]: a lake already
/// being warmed still finishes. `onLakeStart` lets the reload progress card
/// show which lake is currently being warmed, since its own site counter
/// stays at zero for this whole phase. A no-op wherever the local cache
/// database is not initialized.
final swissBathyWarmKnownSitesProvider =
    Provider<
      Future<void> Function({
        required bool Function() isCancelled,
        void Function(String lakeName, int index, int total)? onLakeStart,
      })
    >((ref) {
      return ({required isCancelled, onLakeStart}) async {
        final source = ref.read(swissBathy3dSourceProvider);
        await source?.warmKnownSites(
          isCancelled: isCancelled,
          onLakeStart: onLakeStart,
        );
      };
    });

/// What the "3D Maps" reload confirmation dialog shows before the diver
/// commits: how many dive sites will be reloaded, and an approximate
/// download size. The estimate is read from data that is still cached at
/// the moment this is computed -- before the reload's own delete step runs
/// -- because averaging from an already-emptied cache would have nothing
/// left to average from.
class MapReloadEstimate {
  final int siteCount;

  /// Null when there is no cached 'ok' row anywhere to average a size from
  /// (e.g. right after a reset). The dialog then shows the site count alone
  /// rather than a fabricated number.
  final int? averageBytesPerSite;

  const MapReloadEstimate({required this.siteCount, this.averageBytesPerSite});

  // siteCount == 0 must also read as "no estimate", not as a fabricated
  // "0 B" -- the cached average can be non-null (e.g. from a location the
  // diver viewed without saving a dive site there) even while there is
  // nothing to reload (found by code review).
  int? get estimatedBytes => averageBytesPerSite == null || siteCount == 0
      ? null
      : averageBytesPerSite! * siteCount;

  String? get formattedEstimatedSize {
    final bytes = estimatedBytes;
    return bytes == null ? null : formatBytes(bytes);
  }
}

// no-tick: reads the same local-only, never-synced cache database
// bathymetryGridProvider does (see that provider's own no-tick comment) --
// there is no merge, bulk-delete, or sync-pull path that can touch it. The
// two writers that actually change what this estimate measures
// (swissBathyClearProvider, bathymetryOtherSourcesClearProvider) already
// call ref.invalidate(mapReloadEstimateProvider) directly; any other write
// (an individual site's own resolve) only makes the estimate more accurate
// over time, never meaningfully stale, since it is a rough approximation
// shown once before a destructive action, not rendered data.
final mapReloadEstimateProvider = FutureProvider<MapReloadEstimate?>((
  ref,
) async {
  final repo = ref.watch(bathymetryRepositoryProvider);
  if (repo == null) return null;
  final sites = await ref.watch(knownDiveSiteLocationsProvider.future);
  final averageBytes = await repo.averageCachedGridBytes();
  return MapReloadEstimate(
    siteCount: sites.length,
    averageBytesPerSite: averageBytes,
  );
});

/// Progress of an in-flight (or just-finished) "reload map data" run.
class MapReloadState {
  final bool isRunning;
  final int total;
  final int completed;
  final bool cancelled;
  final String? error;

  /// When the per-site loop itself started, i.e. AFTER clearing and
  /// warming, not when the diver pressed the button -- the UI's remaining-
  /// time estimate divides elapsed time since here by [completed], and
  /// including the warm phase's own variable, site-count-independent
  /// duration would skew that estimate. Null until the loop actually
  /// starts.
  final DateTime? startedAt;

  /// When the diver pressed the button, i.e. BEFORE clearing/warming --
  /// unlike [startedAt], covers the whole run. Used only for the "running
  /// for..." elapsed-time display, which is deliberately meant to cover the
  /// whole run including clearing.
  final DateTime? overallStartedAt;

  /// When the warm phase itself began, i.e. AFTER clearing but BEFORE the
  /// first lake starts -- the warm-phase counterpart of [startedAt]. The
  /// warm-phase remaining-time estimate divides elapsed time since here by
  /// the number of lakes finished so far; using [overallStartedAt] instead
  /// would fold the (site-count-independent, sometimes multi-second)
  /// clearing duration into that rate, inflating the estimate for exactly
  /// as long as clearing took, worst right after the first lake finishes
  /// (found by code review).
  final DateTime? warmStartedAt;

  /// The lake [SwissBathy3dSource.warmKnownSites] is currently warming, its
  /// 1-based position, and the total lake count -- null once that phase
  /// ends (see [copyWith]'s `clearWarming`). The only progress signal the
  /// warm phase has to show, since [completed]/[total] stay at their
  /// per-site meaning and do not move during this phase.
  final String? warmingLakeName;
  final int warmingLakeIndex;
  final int warmingLakeTotal;

  const MapReloadState({
    this.isRunning = false,
    this.total = 0,
    this.completed = 0,
    this.cancelled = false,
    this.error,
    this.startedAt,
    this.overallStartedAt,
    this.warmStartedAt,
    this.warmingLakeName,
    this.warmingLakeIndex = 0,
    this.warmingLakeTotal = 0,
  });

  MapReloadState copyWith({
    bool? isRunning,
    int? total,
    int? completed,
    bool? cancelled,
    String? error,
    bool clearError = false,
    DateTime? startedAt,
    DateTime? overallStartedAt,
    DateTime? warmStartedAt,
    String? warmingLakeName,
    int? warmingLakeIndex,
    int? warmingLakeTotal,
    bool clearWarming = false,
  }) {
    return MapReloadState(
      isRunning: isRunning ?? this.isRunning,
      total: total ?? this.total,
      completed: completed ?? this.completed,
      cancelled: cancelled ?? this.cancelled,
      error: clearError ? null : (error ?? this.error),
      startedAt: startedAt ?? this.startedAt,
      overallStartedAt: overallStartedAt ?? this.overallStartedAt,
      warmStartedAt: warmStartedAt ?? this.warmStartedAt,
      warmingLakeName: clearWarming
          ? null
          : (warmingLakeName ?? this.warmingLakeName),
      warmingLakeIndex: clearWarming
          ? 0
          : (warmingLakeIndex ?? this.warmingLakeIndex),
      warmingLakeTotal: clearWarming
          ? 0
          : (warmingLakeTotal ?? this.warmingLakeTotal),
    );
  }
}

/// Runs the "3D Maps" reload action: clears every cached bathymetry row
/// (both swissBATHY3D and the other providers), then walks every known dive
/// site and re-fetches its grid, one at a time.
///
/// Sequential, not parallel: the other four providers have no concurrency
/// limiter of their own, unlike swissBATHY3D's internal bounded tile pool,
/// so fetching many sites at once here would hammer them uncontrolled.
///
/// [cancel] only stops scheduling further sites; it cannot abort a site's
/// own in-flight request, since none of the five bathymetry sources
/// currently support request cancellation. The site already in flight when
/// cancel is pressed still completes (and counts) before the loop stops.
class MapReloadNotifier extends StateNotifier<MapReloadState> {
  final Ref _ref;
  bool _cancelRequested = false;

  MapReloadNotifier(this._ref) : super(const MapReloadState());

  Future<void> start() async {
    if (state.isRunning) return;
    _cancelRequested = false;
    state = MapReloadState(isRunning: true, overallStartedAt: DateTime.now());
    try {
      // A reload can run for minutes across many sites/lakes; without this,
      // the OS can lock the screen and suspend the fetch loop mid-run --
      // the same failure mode ScreenAwake was written to prevent for sync
      // maintenance (issue #1194) and dive-computer downloads (#1646),
      // missing here until code review pointed it out.
      await ScreenAwake.hold(() async {
        await _ref.read(swissBathyClearProvider)();
        await _ref.read(bathymetryOtherSourcesClearProvider)();

        // refresh, not read: this FutureProvider memoizes its list for the
        // whole app session, so a dive site added or pulled in by sync
        // since the last read would be silently left out of the reload --
        // the very sites a diver is most likely to be reloading for
        // (found by code review). The sibling pre-cache path never had
        // this problem: it calls the underlying query directly rather
        // than through the memoizing wrapper.
        final sites = await _ref.refresh(knownDiveSiteLocationsProvider.future);
        final repo = _ref.read(bathymetryRepositoryProvider);
        if (repo == null) {
          // The clears above and every getGrid() call below silently no-op
          // wherever the local cache database is not initialized -- without
          // this check the loop would "complete" every site without ever
          // clearing or fetching anything, and the caller would report
          // success for a run that did nothing.
          state = state.copyWith(error: 'local cache database not initialized');
          return;
        }
        state = state.copyWith(
          total: sites.length,
          // Marks the start of the warm phase's own pace -- see
          // [MapReloadState.warmStartedAt]'s doc on why this must be its
          // own timestamp, not overallStartedAt.
          warmStartedAt: DateTime.now(),
        );

        // Warm every swissBATHY3D dive site's tile, grouped by lake and
        // awaited, BEFORE the per-site loop below -- otherwise each Swiss
        // lake site in that loop would pay for its own from-scratch zip
        // download and decompress instead of reusing a sibling site's
        // already-warm lake (see swissBathyWarmKnownSitesProvider's own doc).
        await _ref.read(swissBathyWarmKnownSitesProvider)(
          isCancelled: () => _cancelRequested,
          onLakeStart: (lakeName, index, total) {
            state = state.copyWith(
              warmingLakeName: lakeName,
              warmingLakeIndex: index,
              warmingLakeTotal: total,
            );
          },
        );

        // Marks the start of the per-site loop's own pace, deliberately
        // after clearing/warming -- see [MapReloadState.startedAt]'s doc.
        // Also clears the warm phase's own progress fields, so the UI
        // switches from "warming lake X of Y" to the per-site counter.
        state = state.copyWith(startedAt: DateTime.now(), clearWarming: true);

        for (final site in sites) {
          if (_cancelRequested) break;
          await repo.getGrid(site);
          state = state.copyWith(completed: state.completed + 1);
        }
      });
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isRunning: false, cancelled: _cancelRequested);
    }
  }

  /// Requests that the reload stop after the site currently in flight.
  void cancel() {
    _cancelRequested = true;
  }

  void reset() {
    state = const MapReloadState();
  }
}

final mapReloadProvider =
    StateNotifierProvider<MapReloadNotifier, MapReloadState>(
      (ref) => MapReloadNotifier(ref),
    );
