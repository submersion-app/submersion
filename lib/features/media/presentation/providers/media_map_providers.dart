import 'dart:async';
import 'dart:math' as math;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';

/// The map mode's data: every located in-scope item plus how many in-scope
/// items could not be placed.
class MediaMapState {
  const MediaMapState({
    this.points = const [],
    this.unlocatedCount = 0,
    this.isLoading = false,
    this.error,
  });

  final List<MediaMapPoint> points;
  final int unlocatedCount;
  final bool isLoading;
  final Object? error;

  MediaMapState copyWith({
    List<MediaMapPoint>? points,
    int? unlocatedCount,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return MediaMapState(
      points: points ?? this.points,
      unlocatedCount: unlocatedCount ?? this.unlocatedCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Located points for the map view mode. Rebuilt when the filter or the
/// active diver changes; reloaded on the map change tick (media, dives and
/// dive_sites writes).
///
/// Explicitly auto-dispose: Riverpod 3 defaults it off, and leaving map
/// mode should release the point list rather than hold it for the process
/// lifetime.
final mediaMapPointsProvider =
    StateNotifierProvider.autoDispose<MediaMapNotifier, MediaMapState>((ref) {
      final repo = ref.watch(mediaLibraryRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(mediaLibraryFilterProvider);
      return MediaMapNotifier(repo, diverId, filter);
    });

class MediaMapNotifier extends StateNotifier<MediaMapState> {
  MediaMapNotifier(this._repo, this._diverId, this._filter)
    : super(const MediaMapState(isLoading: true)) {
    _changesSub = _repo.watchMapChanges().listen((_) => load());
    load();
  }

  final MediaLibraryRepository _repo;
  final String? _diverId;
  final MediaLibraryFilter _filter;
  StreamSubscription<void>? _changesSub;

  Future<void> load() async {
    // Keep the points on screen while reloading, as the grid does: emptying
    // them would unmount every marker and re-resolve every thumbnail.
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final points = await _repo.getMapPoints(
        diverId: _diverId,
        filter: _filter,
      );
      final total = await _repo.countInScope(
        diverId: _diverId,
        filter: _filter,
      );
      if (!mounted) return;
      state = MediaMapState(
        points: points,
        unlocatedCount: math.max(0, total - points.length),
      );
    } catch (e) {
      if (!mounted) return;
      state = MediaMapState(
        points: state.points,
        unlocatedCount: state.unlocatedCount,
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
