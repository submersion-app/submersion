import 'package:flutter/foundation.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// What one completed resolution produced.
///
/// [storeFallbackUsed] is the fact no resolver can report on its own: it
/// belongs to the layer that tried the row's native source first, saw it
/// fail, and asked the media store to cover. It is what turns "the cloud
/// served this" into "the photo library lookup failed and the cloud served
/// this", which is the difference between a status readout and a diagnosis.
@immutable
class ServingObservation {
  const ServingObservation({
    required this.servedFrom,
    required this.servedTier,
    required this.failure,
    required this.storeFallbackUsed,
    required this.observedAt,
  });

  final ServedFrom? servedFrom;
  final ServedTier servedTier;

  /// Set when the resolution produced no bytes at all.
  final UnavailableKind? failure;

  /// Whether the row's own source failed and the media store was asked.
  /// Records that the fallback RAN, not that it succeeded.
  final bool storeFallbackUsed;

  final DateTime observedAt;
}

/// Remembers how each media item was most recently resolved, so the media
/// info panel can report what actually painted the pixels rather than
/// re-resolving and reporting what would happen if it tried again.
///
/// Deliberately NOT a StateNotifier or a Riverpod-managed state object.
/// Every visible tile writes here as it finishes resolving, and routing
/// that through provider state would rebuild the grid on every scroll.
/// Listeners are notified so an open info panel can refresh; when nothing
/// is listening, notification is free.
class MediaServingRecorder extends ChangeNotifier {
  MediaServingRecorder({DateTime Function()? now, this.maxEntries = 200})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Bound on retained observations. A library scroll would otherwise grow
  /// this map without limit for the lifetime of the process.
  final int maxEntries;

  /// Insertion-ordered, so the first key is the least recently recorded.
  /// A re-record removes and re-inserts to move the entry to the end.
  final Map<String, ServingObservation> _entries =
      <String, ServingObservation>{};

  @visibleForTesting
  int get entryCount => _entries.length;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// A thumbnail and an original are separate observations of the same row:
  /// a grid tile resolves the first while the viewer resolves the second,
  /// and they can legitimately come from different places.
  String _key(String mediaId, bool thumbnail) =>
      '$mediaId#${thumbnail ? 't' : 'o'}';

  void record(
    String mediaId, {
    required bool thumbnail,
    ServedFrom? servedFrom,
    ServedTier servedTier = ServedTier.original,
    UnavailableKind? failure,
    bool storeFallbackUsed = false,
  }) {
    // A resolution can outlive the container that owns this recorder: a
    // FutureProvider still in flight when a ProviderContainer is disposed
    // runs its continuation afterwards. notifyListeners asserts once the
    // notifier is disposed, so a late write is dropped rather than attempted.
    if (_disposed) return;
    final key = _key(mediaId, thumbnail);
    _entries.remove(key);
    _entries[key] = ServingObservation(
      servedFrom: servedFrom,
      servedTier: servedTier,
      failure: failure,
      storeFallbackUsed: storeFallbackUsed,
      observedAt: _now(),
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    notifyListeners();
  }

  ServingObservation? lastFor(String mediaId, {required bool thumbnail}) =>
      _entries[_key(mediaId, thumbnail)];
}
