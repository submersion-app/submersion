import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

final _log = LoggerService.forClass(DiveProfileBatcher);

/// Fetches the dive list's mini profiles into [batchProfileCacheProvider],
/// never fetching a dive while it is already being fetched.
class DiveProfileBatcher {
  DiveProfileBatcher(this._ref);

  final Ref _ref;
  final _inFlight = <String>{};
  final _requested = <String>{};
  final _queued = <String>{};
  bool _disposed = false;

  /// For a card built without its profile: queues [diveId] into one batch
  /// per microtask, unless it is cached, being fetched or was requested
  /// before.
  void request(String diveId) {
    if (_disposed ||
        _requested.contains(diveId) ||
        _inFlight.contains(diveId) ||
        _ref.read(batchProfileCacheProvider).containsKey(diveId)) {
      return;
    }
    if (_queued.isEmpty) scheduleMicrotask(_flush);
    _queued.add(diveId);
  }

  void _flush() {
    final ids = _queued.toList(growable: false);
    _queued.clear();
    _requested.addAll(ids);
    unawaited(load(ids));
  }

  /// Fetches the profiles of [diveIds] now, skipping cached ones and ones
  /// already being fetched.
  Future<void> load(List<String> diveIds) async {
    if (_disposed || diveIds.isEmpty) return;
    final cache = _ref.read(batchProfileCacheProvider);
    final ids = [
      for (final id in diveIds)
        if (!cache.containsKey(id) && _inFlight.add(id)) id,
    ];
    if (ids.isEmpty) return;
    try {
      final profiles = await _ref
          .read(diveRepositoryProvider)
          .getBatchProfileSummaries(ids);
      if (_disposed) return;
      mergeIntoBatchProfileCache(
        _ref.read(batchProfileCacheProvider.notifier),
        profiles,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to fetch dive list profiles',
        error: e,
        stackTrace: stackTrace,
      );
      // Not fetched, so a card built again may ask again.
      _requested.removeAll(ids);
    } finally {
      _inFlight.removeAll(ids);
    }
  }

  void _dispose() => _disposed = true;
}

/// The dive list's one [DiveProfileBatcher].
final diveProfileBatcherProvider = Provider<DiveProfileBatcher>((ref) {
  final batcher = DiveProfileBatcher(ref);
  ref.onDispose(batcher._dispose);
  return batcher;
});
