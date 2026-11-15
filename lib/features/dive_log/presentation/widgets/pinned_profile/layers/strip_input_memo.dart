/// Keeps what the pinned strip's layer host derives from its providers, so a
/// rebuild with the same provider values hands back the very same objects
/// and the layer data built from them is reused (issue #4562).
///
/// Each slot remembers the keys its value was built from. Objects compare by
/// identity (a provider's value is the same object while it is unchanged);
/// strings, numbers, booleans and null by equality.
class StripInputMemo {
  final Map<String, (List<Object?>, Object?)> _slots = {};

  /// The value of [slot] built from [keys], building it with [build] only
  /// when the keys differ from the last ones.
  T remember<T>(String slot, List<Object?> keys, T Function() build) {
    final kept = _slots[slot];
    if (kept != null && _same(kept.$1, keys)) return kept.$2 as T;
    final value = build();
    _slots[slot] = (List.unmodifiable(keys), value);
    return value;
  }

  static bool _same(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      final plain = x == null || x is String || x is num || x is bool;
      if (plain ? x != y : !identical(x, y)) return false;
    }
    return true;
  }
}
