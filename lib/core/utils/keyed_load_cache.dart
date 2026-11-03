/// A value loaded once per key and kept, unless the load fails: the next
/// [get] loads again. Only the newest key's value is kept, and a load that
/// fails after a newer one started leaves the newer one in place.
class KeyedLoadCache<K, V> {
  KeyedLoadCache(this._load);

  final Future<V> Function(K key) _load;
  K? _key;
  Future<V>? _value;

  Future<V> get(K key) {
    final kept = _value;
    if (kept != null && _key == key) return kept;
    final load = _load(key);
    _key = key;
    _value = load;
    // The caller hears the failure on [load] itself; this only forgets it.
    load.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_value, load)) _value = null;
      },
    );
    return load;
  }
}
