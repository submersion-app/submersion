/// Thrown when an operation that would destroy a dive's stored samples
/// cannot read them first.
///
/// Merge and consolidate re-base their sources onto a combined timeline and
/// then delete the source dives, so both have to decode every series they
/// carry across. A blob this build cannot decode is not necessarily corrupt
/// (a series written by a newer codec version can sync back to an older
/// device), but either way it cannot be re-based, and the dive holding it
/// is the last copy. Refusing leaves the data where it is.
class UnreadableSeriesException implements Exception {
  const UnreadableSeriesException(this.seriesIds);

  /// The series rows that would not decode.
  final List<String> seriesIds;

  @override
  String toString() =>
      'UnreadableSeriesException: ${seriesIds.length} series could not be '
      'decoded (${seriesIds.join(', ')}); the dives holding them were left '
      'untouched';
}
