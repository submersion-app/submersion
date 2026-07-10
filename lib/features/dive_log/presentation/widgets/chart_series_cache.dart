/// Memoizes a chart's series lists by key, with a per-key data signature.
///
/// Within one signature a key's rebuilds -- driven purely by interaction
/// state (playback ticks, hover, zoom inside the same decimation bucket) --
/// are pure cache hits and never reconstruct the series. When a key's
/// signature changes (its data, units, visibility, viewport bucket, or
/// theme), ONLY that key rebuilds: an analysis-curve re-emission (for
/// example a ceiling-source toggle) leaves the depth/temperature/pressure
/// series untouched (WS3, large-DB performance).
class ChartSeriesCache<T> {
  final Map<String, ({String signature, List<T> series})> _cache = {};

  /// Returns the cached series for [key] when [signature] matches the last
  /// build; otherwise builds once via [build] and caches the result.
  List<T> series(String key, String signature, List<T> Function() build) {
    final hit = _cache[key];
    if (hit != null && hit.signature == signature) return hit.series;
    final built = build();
    _cache[key] = (signature: signature, series: built);
    return built;
  }
}
