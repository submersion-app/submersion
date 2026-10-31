import 'dart:async';

import 'package:submersion/features/dive_log/data/repositories/dive_list_snapshot.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Keeps a hydrated dive list current at the cost of what changed (#3815).
///
/// [refresh] reuses the dives it holds unless a table they embed was written
/// since they were loaded. That write has no way to say which dives it
/// touched, and may touch every dive at a site, so the refresh after it loads
/// the whole list: a dive row's digest cannot see outside the row. So does
/// every refresh once the database that write report came from has closed,
/// since a write to its replacement would go unseen.
///
/// Only the newest load lands. One overtaken by a later load, or by [cancel],
/// answers null however it ended, so a list loaded for the previous diver
/// never replaces the current one.
class DiveListLoader {
  DiveListLoader(this._repository) {
    _hydrationWrites = _repository.watchDiveHydrationWrites().listen(
      (_) => _hydrationWriteCount++,
      onDone: () => _hydrationWritesEnded = true,
    );
  }

  final DiveRepository _repository;
  late final StreamSubscription<void> _hydrationWrites;

  DiveListSnapshot? _snapshot;

  /// [_hydrationWriteCount] as [_snapshot]'s load began. A count, not a flag:
  /// a write during a load must still read as unseen once the load lands.
  int _snapshotHydrationWrites = 0;
  int _hydrationWriteCount = 0;
  bool _hydrationWritesEnded = false;
  int _latestLoad = 0;

  /// The whole list, trusting nothing held.
  Future<List<Dive>?> load({String? diverId}) {
    _snapshot = null;
    return refresh(diverId: diverId);
  }

  /// The list, if it changed from what this loader last returned. Null when
  /// nothing did, or when a newer load overtook this one.
  Future<List<Dive>?> refresh({String? diverId}) async {
    final generation = ++_latestLoad;
    // Drift reports a write a turn after the write's own future completes, so
    // a reload right behind a write lets that report land before counting.
    await Future<void>.delayed(Duration.zero);
    if (generation != _latestLoad) return null;
    final writes = _hydrationWriteCount;
    final previous =
        writes == _snapshotHydrationWrites && !_hydrationWritesEnded
        ? _snapshot
        : null;
    try {
      final snapshot = await _repository.getDiveListSnapshot(
        diverId: diverId,
        previous: previous,
      );
      if (generation != _latestLoad) return null;
      _snapshot = snapshot;
      _snapshotHydrationWrites = writes;
      return identical(snapshot, previous) ? null : snapshot.dives;
    } catch (_) {
      if (generation != _latestLoad) return null;
      _snapshot = null;
      rethrow;
    }
  }

  /// The list, for a caller that needs one whether or not it changed. When a
  /// newer load overtook this one this is the last list that landed, so only a
  /// caller that discards an overtaken answer, as a provider rebuild does, can
  /// use it.
  Future<List<Dive>> latest({String? diverId}) async {
    await refresh(diverId: diverId);
    return _snapshot?.dives ?? const [];
  }

  void cancel() {
    _latestLoad++;
    _hydrationWrites.cancel();
  }
}
