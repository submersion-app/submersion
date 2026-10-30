import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/services/volume_status.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/utils/log_failure.dart';

/// Library browse presentations. Values are persisted by name via the app
/// settings key-value store; an unknown stored name falls back to [grid],
/// which is what makes adding a value here migration-free.
enum MediaLibraryViewMode { grid, byDive, timeline, map }

final mediaLibraryRepositoryProvider = Provider<MediaLibraryRepository>((ref) {
  return MediaLibraryRepository();
});

/// The active library filter. Writing this rebuilds
/// [mediaLibraryNotifierProvider], which reloads page one — deliberately
/// coarse (no per-row patching) per the Media section spec.
final mediaLibraryFilterProvider = StateProvider<MediaLibraryFilter>(
  (ref) => MediaLibraryFilter.none,
);

/// Persisted view mode for the library (grid / by dive / timeline / map).
final mediaLibraryViewModeProvider =
    StateNotifierProvider<MediaLibraryViewModeNotifier, MediaLibraryViewMode>((
      ref,
    ) {
      return MediaLibraryViewModeNotifier(
        ref.watch(appSettingsRepositoryProvider),
      );
    });

class MediaLibraryViewModeNotifier extends StateNotifier<MediaLibraryViewMode> {
  MediaLibraryViewModeNotifier(this._settings)
    : super(MediaLibraryViewMode.grid) {
    logFailure(_prime(), MediaLibraryViewModeNotifier, 'prime');
  }

  static const String _settingKey = 'media_library_view_mode';
  final AppSettingsRepository _settings;

  Future<void> _prime() async {
    final raw = await _settings.getRawSetting(_settingKey);
    if (!mounted || raw == null) return;
    for (final mode in MediaLibraryViewMode.values) {
      if (mode.name == raw) {
        state = mode;
        return;
      }
    }
  }

  Future<void> setMode(MediaLibraryViewMode mode) async {
    state = mode;
    await _settings.setRawSetting(_settingKey, mode.name);
  }
}

/// Accumulated library pages plus load status.
class MediaLibraryState extends Equatable {
  const MediaLibraryState({
    this.entries = const [],
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<MediaLibraryEntry> entries;
  final MediaLibraryCursor? nextCursor;

  /// First page in flight (entries are stale or empty).
  final bool isLoading;

  /// A subsequent page in flight (entries are valid and growing).
  final bool isLoadingMore;

  final Object? error;

  bool get hasMore => nextCursor != null;

  MediaLibraryState copyWith({
    List<MediaLibraryEntry>? entries,
    MediaLibraryCursor? nextCursor,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
  }) {
    return MediaLibraryState(
      entries: entries ?? this.entries,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    entries,
    nextCursor,
    isLoading,
    isLoadingMore,
    error,
  ];
}

/// Paged library notifier. Rebuilt whenever the filter, sort, or active diver
/// changes; re-reads the rows it has loaded whenever a table behind them
/// changes.
final mediaLibraryNotifierProvider =
    StateNotifierProvider<MediaLibraryNotifier, MediaLibraryState>((ref) {
      final repo = ref.watch(mediaLibraryRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(mediaLibraryFilterProvider);
      final sort = ref.watch(mediaLibrarySortProvider);
      return MediaLibraryNotifier(repo, diverId, filter, sort);
    });

class MediaLibraryNotifier extends StateNotifier<MediaLibraryState> {
  MediaLibraryNotifier(this._repo, this._diverId, this._filter, this._sort)
    : super(const MediaLibraryState()) {
    _changesSub = _repo.watchLibraryChanges().listen(
      (_) => _refreshAfterChange(),
    );
    loadFirstPage();
  }

  final MediaLibraryRepository _repo;
  final String? _diverId;
  final MediaLibraryFilter _filter;
  final SortState<MediaSortField> _sort;
  StreamSubscription<void>? _changesSub;

  /// Serializes every read that rewrites the loaded rows.
  ///
  /// Left to overlap, whichever read finished last would decide what is on
  /// screen, not whichever started last, and a page could land on rows a
  /// reload had just replaced. One at a time, each read starts from a state
  /// that is still current when it writes, and a read that may have missed a
  /// write always has another behind it. This is the whole policy: the query
  /// cannot change under a read, because a new filter, sort or diver builds a
  /// new notifier.
  Future<void> _pagingQueue = Future<void>.value();

  /// A refresh is queued and has not started reading. Any change landing now
  /// joins it, since it will see that change anyway.
  bool _refreshQueued = false;

  /// Runs [op] after every read queued before it.
  ///
  /// The returned future carries [op]'s own error; the queue keeps a swallowed
  /// copy so one failed read cannot wedge every read after it.
  Future<void> _enqueuePaging(Future<void> Function() op) {
    final next = _pagingQueue.then((_) => op());
    _pagingQueue = next.catchError((_) {});
    return next;
  }

  /// Reads page one, or every loaded row once there are more than a page.
  ///
  /// [MediaLibraryState.isLoading] goes up now, not when the queue gets here:
  /// the view's first build reads it straight after the constructor, and
  /// would show the empty-library text in the meantime.
  Future<void> loadFirstPage() {
    state = state.copyWith(isLoading: true);
    return _enqueuePaging(_reloadLoadedRows);
  }

  /// A write landed. However long a burst of them lasts, at most one read
  /// runs and one waits behind it.
  void _refreshAfterChange() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    _enqueuePaging(() {
      _refreshQueued = false;
      return _reloadLoadedRows();
    });
  }

  /// Re-reads every loaded row from the top, in one query.
  ///
  /// As many rows as are loaded, not page one. Shrinking to page one on every
  /// write threw away the rows the diver had scrolled past, their place in the
  /// list and any selection among them. This read still drops rows that were
  /// deleted or stopped matching and takes in new ones, and it leaves the
  /// cursor on its own last row, so [loadMore] carries on with no gap. A
  /// library read to its end asks for a page more: a new row would otherwise
  /// push the oldest out with nothing to bring it back, and nothing starts a
  /// load until the next scroll.
  ///
  /// The rows stay on screen meanwhile. Emptying them would trip the view's
  /// first-load spinner, which replaces the whole grid and so disposes every
  /// tile, and each tile re-resolves from initState when it remounts. Kept
  /// mounted, a tile re-resolves only if its own row changed, since
  /// MediaItemView compares items by value.
  Future<void> _reloadLoadedRows() async {
    // Queued work can reach its turn after the notifier is gone, and writing
    // state on a disposed StateNotifier throws.
    if (!mounted) return;
    final loaded = state.entries.length;
    try {
      final page = await _repo.getPage(
        diverId: _diverId,
        filter: _filter,
        sort: _sort,
        limit: state.hasMore
            ? loaded
            : loaded + MediaLibraryRepository.pageSize,
      );
      if (!mounted) return;
      // isLoadingMore is read here, not before the await: [loadMore] raises it
      // at once and queues its read behind this one.
      final next = MediaLibraryState(
        entries: page.entries,
        nextCursor: page.nextCursor,
        isLoadingMore: state.isLoadingMore,
      );
      // Most writes change nothing here (an upload stamp on a row off this
      // filter, a trip rename). Writing anyway rebuilds the view and regroups
      // every loaded row.
      if (next != state) state = next;
    } catch (e) {
      if (!mounted) return;
      // The rows are still the best answer there is: a failed read says
      // nothing about them, and with none the view reads as an empty library.
      state = MediaLibraryState(
        entries: state.entries,
        nextCursor: state.nextCursor,
        isLoadingMore: state.isLoadingMore,
        error: e,
      );
    }
  }

  Future<void> loadMore() {
    // Cheap pre-check so a burst of scroll notifications cannot queue the same
    // page a hundred times. The queued read decides for real, since a reload
    // ahead of it may have moved the cursor.
    if (state.nextCursor == null || state.isLoadingMore) {
      return Future<void>.value();
    }
    state = state.copyWith(isLoadingMore: true);
    return _enqueuePaging(_loadNextPage);
  }

  Future<void> _loadNextPage() async {
    if (!mounted) return;
    final cursor = state.nextCursor;
    if (cursor == null) {
      // A reload ahead of this one reached the end of the library.
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    try {
      final page = await _repo.getPage(
        diverId: _diverId,
        filter: _filter,
        sort: _sort,
        after: cursor,
      );
      if (!mounted) return;
      // A write can move a loaded row past the cursor (hashing a row sets its
      // size); the refresh that write ticks has not landed yet. Appending by
      // id keeps the row from showing twice until it does.
      final loaded = state.entries.map((e) => e.item.id).toSet();
      state = MediaLibraryState(
        entries: [
          ...state.entries,
          ...page.entries.where((e) => !loaded.contains(e.item.id)),
        ],
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      if (!mounted) return;
      state = MediaLibraryState(
        entries: state.entries,
        nextCursor: cursor,
        error: e,
      );
    }
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _changesSub = null;
    super.dispose();
  }
}

/// Missing-files count for the Library badge and the Missing files chip.
final missingCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(mediaLibraryRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchMediaChanges());
  return repo.countMissing();
});

/// Of the rows currently shown by the Missing filter, how many sit on
/// unmounted volumes (informational: those are offline, not broken, and
/// the repair wizard skips them). One probe per mount root per pass; a
/// fresh probe each time the provider recomputes, so remounting is picked
/// up.
///
/// Only the repair banner watches this, and the banner is only mounted
/// while the Missing files facet is active. autoDispose tears the provider
/// down when the banner goes, and the facet check below means the volume
/// probes never run against a page the facet is not filtering.
final missingOfflineCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final health = ref.watch(mediaLibraryFilterProvider.select((f) => f.health));
  if (health != MediaHealthFilter.missing) return 0;
  final state = ref.watch(mediaLibraryNotifierProvider);
  final isOnline = VolumeStatus().newPassProbe();
  var offline = 0;
  for (final entry in state.entries) {
    if (!entry.item.isOrphaned) continue;
    final path = entry.item.localPath ?? entry.item.filePath;
    if (path == null || path.isEmpty) continue;
    if (!await isOnline(path)) offline++;
  }
  return offline;
});
