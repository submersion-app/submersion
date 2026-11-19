import 'dart:ui' show Size;

import 'package:flutter/scheduler.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';

final mediaAspectCacheRepositoryProvider = Provider<MediaAspectCacheRepository>(
  (ref) => MediaAspectCacheRepository(),
);

/// The shapes learned from library thumbnails, keyed by media id (issue
/// #4738). Loaded once and kept for the session: the library lays out from
/// it, and a tile reports its decoded size here.
final mediaLearnedAspectsProvider =
    AsyncNotifierProvider<
      MediaLearnedAspectsNotifier,
      Map<String, LearnedAspect>
    >(MediaLearnedAspectsNotifier.new);

class MediaLearnedAspectsNotifier
    extends AsyncNotifier<Map<String, LearnedAspect>> {
  final _log = LoggerService.forClass(
    MediaLearnedAspectsNotifier,
    category: LogCategory.media,
  );

  /// Shapes reported since the last flush, not yet in [state].
  final Map<String, LearnedAspect> _pending = {};
  bool _flushScheduled = false;

  /// A cache that cannot be read costs the learned shapes, not the library:
  /// the gallery lays out from stored sizes and learns again as it draws.
  @override
  Future<Map<String, LearnedAspect>> build() async {
    try {
      return await ref.watch(mediaAspectCacheRepositoryProvider).loadAll();
    } on Object catch (error, stack) {
      _log.warning(
        'Could not read learned thumbnail shapes',
        error: error,
        stackTrace: stack,
      );
      return const {};
    }
  }

  /// Called by a library tile with its thumbnail's decoded [decoded] size.
  ///
  /// Records the decoded shape when it differs from the one [item] is laid
  /// out at, which is what catches a photo stored sideways with an EXIF
  /// rotation. Documents keep their fixed shape. Reports wait for the end of
  /// the frame and go out together: one re-layout, one write.
  void report(MediaItem item, Size decoded) {
    if (item.mediaType == MediaType.document) return;
    if (decoded.width <= 0 || decoded.height <= 0) return;
    final known = _pending[item.id] ?? state.value?[item.id];
    final raw = mediaRawAspect(item, learned: known);
    if (!decodedAspectDiffers(raw, decoded)) return;
    _pending[item.id] = (
      ratio: decoded.width / decoded.height,
      width: item.width,
      height: item.height,
    );
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _flush())
      ..ensureVisualUpdate();
  }

  void _flush() {
    _flushScheduled = false;
    // The frame can end after the provider has gone (a closed scope).
    if (!ref.mounted || _pending.isEmpty) return;
    final current = state.value;
    if (current == null) {
      // Still loading: flush once the stored shapes are in.
      future.then((_) => _scheduleFlush(), onError: (_) => _scheduleFlush());
      return;
    }
    final batch = Map.of(_pending);
    _pending.clear();
    state = AsyncData({...current, ...batch});
    ref
        .read(mediaAspectCacheRepositoryProvider)
        .putAll(batch)
        .catchError(
          (Object error, StackTrace stack) => _log.warning(
            'Could not store learned thumbnail shapes',
            error: error,
            stackTrace: stack,
          ),
        );
  }
}
