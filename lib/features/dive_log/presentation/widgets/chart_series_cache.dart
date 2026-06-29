/// Memoizes a chart's series lists by key. The whole cache is dropped whenever
/// the data signature changes (data, units, visibility, or theme); within one
/// signature, rebuilds driven purely by interaction state (playback ticks,
/// hover, zoom) are pure cache hits and never reconstruct the series. A
/// visibility (legend) or theme change is part of the signature and so does
/// rebuild.
class ChartSeriesCache<T> {
  final Map<String, List<T>> _cache = {};
  String? _signature;

  /// Drops all cached series if [dataSignature] differs from the last one.
  void invalidate(String dataSignature) {
    if (dataSignature != _signature) {
      _cache.clear();
      _signature = dataSignature;
    }
  }

  /// Returns the cached series for [key], building once via [build] on a miss.
  List<T> series(String key, List<T> Function() build) =>
      _cache[key] ??= build();
}
