/// Chunking for `id IN (...)` predicates over a list of dive or series ids.
///
/// Shared by the two series repositories, which both bind one SQL variable
/// per id and both reach beyond a single dive (a library-wide computer
/// clear, a whole filtered library's dive ids). SQLite's default
/// SQLITE_MAX_VARIABLE_NUMBER is 32,766; 900 matches
/// `DecoClassificationCacheRepository` and `SpeciesRepository` rather than
/// sitting on the ceiling.
library;

/// Rows per statement for a bound-variable list.
const int kSeriesIdChunkSize = 900;

/// [ids] in runs of at most [kSeriesIdChunkSize], in order.
Iterable<List<String>> seriesIdChunks(List<String> ids) sync* {
  for (var start = 0; start < ids.length; start += kSeriesIdChunkSize) {
    final end = start + kSeriesIdChunkSize < ids.length
        ? start + kSeriesIdChunkSize
        : ids.length;
    yield ids.sublist(start, end);
  }
}
