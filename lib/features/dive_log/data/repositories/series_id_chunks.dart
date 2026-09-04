/// Chunking for a list of dive or series ids.
///
/// Shared by the two series repositories, which both bind one SQL variable
/// per id and both reach beyond a single dive (a library-wide computer
/// clear, a whole filtered library's dive ids). SQLite's default
/// SQLITE_MAX_VARIABLE_NUMBER is 32,766; 900 matches
/// `DecoClassificationCacheRepository` and `SpeciesRepository` rather than
/// sitting on the ceiling.
///
/// The logbook PDF export passes a much smaller [size]: its limit is peak
/// memory (a chunk's raw samples are thinned before the next is read), not
/// bound variables. The boundary arithmetic is the same either way, and a
/// dropped tail chunk is silent in both, so it lives here once.
library;

/// Rows per statement for a bound-variable list.
const int kSeriesIdChunkSize = 900;

/// [ids] in runs of at most [size], in order, covering every id exactly once.
///
/// An exact multiple yields no empty trailing chunk, and an empty [ids] yields
/// nothing at all.
Iterable<List<String>> seriesIdChunks(
  List<String> ids, {
  int size = kSeriesIdChunkSize,
}) sync* {
  assert(size > 0, 'chunk size must be positive, or this never terminates');
  for (var start = 0; start < ids.length; start += size) {
    final end = start + size < ids.length ? start + size : ids.length;
    yield ids.sublist(start, end);
  }
}
