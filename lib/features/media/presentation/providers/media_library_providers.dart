import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Library browse presentations. Values are persisted by name via the app
/// settings key-value store.
enum MediaLibraryViewMode { grid, byDive, timeline }

final mediaLibraryRepositoryProvider = Provider<MediaLibraryRepository>((ref) {
  return MediaLibraryRepository();
});

/// The active library filter. Writing this rebuilds
/// [mediaLibraryNotifierProvider], which reloads page one — deliberately
/// coarse (no per-row patching) per the Media section spec.
final mediaLibraryFilterProvider = StateProvider<MediaLibraryFilter>(
  (ref) => MediaLibraryFilter.none,
);

/// Persisted view mode for the library (grid / by dive / timeline).
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
    _prime();
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
class MediaLibraryState {
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
}

/// Paged library notifier. Rebuilt whenever the filter or active diver
/// changes; refreshed (page one reload) whenever the media table changes.
final mediaLibraryNotifierProvider =
    StateNotifierProvider<MediaLibraryNotifier, MediaLibraryState>((ref) {
      final repo = ref.watch(mediaLibraryRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(mediaLibraryFilterProvider);
      return MediaLibraryNotifier(repo, diverId, filter);
    });

class MediaLibraryNotifier extends StateNotifier<MediaLibraryState> {
  MediaLibraryNotifier(this._repo, this._diverId, this._filter)
    : super(const MediaLibraryState()) {
    _changesSub = _repo.watchMediaChanges().listen((_) => loadFirstPage());
    loadFirstPage();
  }

  final MediaLibraryRepository _repo;
  final String? _diverId;
  final MediaLibraryFilter _filter;
  StreamSubscription<void>? _changesSub;

  Future<void> loadFirstPage() async {
    // Keep the entries already on screen while refreshing. Emptying them here
    // trips the library view's first-load spinner, which replaces the whole
    // grid and so disposes every tile -- and each tile re-resolves from
    // initState when it remounts. That churn is invisible but real on any
    // media change (writing metadata, a transfer completing), and the library
    // page now stays mounted underneath a pushed dive detail. A genuine first
    // load still shows the spinner, because entries are empty then anyway.
    state = state.copyWith(isLoading: true);
    try {
      final page = await _repo.getPage(diverId: _diverId, filter: _filter);
      if (!mounted) return;
      state = MediaLibraryState(
        entries: page.entries,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      if (!mounted) return;
      state = MediaLibraryState(error: e);
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.getPage(
        diverId: _diverId,
        filter: _filter,
        after: cursor,
      );
      if (!mounted) return;
      state = MediaLibraryState(
        entries: [...state.entries, ...page.entries],
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

/// Unlinked-media count for the console badge (Phase 2 section).
final unlinkedCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(mediaLibraryRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchMediaChanges());
  return repo.countUnlinked();
});

/// Missing-files count for the console badge (Phase 3 section).
final missingCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(mediaLibraryRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchMediaChanges());
  return repo.countMissing();
});
