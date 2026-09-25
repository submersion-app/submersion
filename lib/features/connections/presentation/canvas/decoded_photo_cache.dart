import 'dart:typed_data';

import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// Decoded node photos, keyed by node, with the race between overlapping
/// syncs closed off.
///
/// A graph change can start a new [sync] while an older one is parked on a
/// decode. Each sync takes a generation number; a decode that lands after a
/// newer sync began is disposed instead of stored, and every image removed
/// or replaced goes through [dispose] exactly once.
class DecodedPhotoCache<T> {
  DecodedPhotoCache({required this.dispose});

  final void Function(T image) dispose;
  final Map<NodeRef, T> _images = {};
  int _generation = 0;

  Map<NodeRef, T> get images => Map.unmodifiable(_images);

  /// Drops images no longer in [wanted], decodes the missing ones in order,
  /// and calls [onChanged] after each change. Returns when this sync has
  /// finished or been superseded.
  Future<void> sync(
    Map<NodeRef, Uint8List> wanted,
    Future<T> Function(Uint8List bytes) decode, {
    void Function()? onChanged,
  }) async {
    final generation = ++_generation;
    for (final ref
        in _images.keys.where((r) => !wanted.containsKey(r)).toList()) {
      dispose(_images.remove(ref) as T);
      onChanged?.call();
    }
    for (final entry in wanted.entries) {
      if (_images.containsKey(entry.key)) continue;
      final T decoded;
      try {
        decoded = await decode(entry.value);
      } catch (_) {
        // A corrupt photo falls back to initials.
        if (generation != _generation) return;
        continue;
      }
      if (generation != _generation) {
        dispose(decoded);
        return;
      }
      final previous = _images[entry.key];
      if (previous != null) dispose(previous);
      _images[entry.key] = decoded;
      onChanged?.call();
    }
  }

  void disposeAll() {
    _generation++;
    for (final img in _images.values) {
      dispose(img);
    }
    _images.clear();
  }
}
