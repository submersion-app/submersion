import 'dart:typed_data';

/// Media bytes a browser fetched from the store (issue #4121), kept in page
/// memory up to [budgetBytes], the least recently used going first. A page
/// has no disk cache to keep them in.
class MediaBytesMemory {
  MediaBytesMemory({this.budgetBytes = defaultBudgetBytes});

  /// Room for a few hundred thumbnails and a handful of full photos.
  static const int defaultBudgetBytes = 64 * 1024 * 1024;

  final int budgetBytes;

  /// Oldest first (a map literal keeps insertion order): a read moves its
  /// entry to the end.
  final _entries = <String, Uint8List>{};
  var _sizeBytes = 0;

  /// What the kept entries add up to.
  int get sizeBytes => _sizeBytes;

  Uint8List? get(String key) {
    final bytes = _entries.remove(key);
    if (bytes != null) _entries[key] = bytes;
    return bytes;
  }

  /// Keeps [bytes] under [key], dropping the least recently used entries
  /// until the budget holds. Bytes larger than the whole budget are not
  /// kept.
  void put(String key, Uint8List bytes) {
    final previous = _entries.remove(key);
    if (previous != null) _sizeBytes -= previous.length;
    if (bytes.length > budgetBytes) return;
    _entries[key] = bytes;
    _sizeBytes += bytes.length;
    while (_sizeBytes > budgetBytes) {
      final oldest = _entries.keys.first;
      _sizeBytes -= _entries.remove(oldest)!.length;
    }
  }
}
