/// The order of two model pack versions (issue #4876): dot-separated parts
/// compared in turn, as numbers where both are (`2026.11.18.0356`), else as
/// text; a version that runs out of parts first is the older. Negative when
/// [a] is older than [b], zero when equal, positive when newer.
int comparePackVersions(String a, String b) {
  final left = a.split('.');
  final right = b.split('.');
  for (var i = 0; i < left.length && i < right.length; i++) {
    final x = int.tryParse(left[i]);
    final y = int.tryParse(right[i]);
    final order = x != null && y != null
        ? x.compareTo(y)
        : left[i].compareTo(right[i]);
    if (order != 0) return order.sign;
  }
  return left.length.compareTo(right.length).sign;
}

/// Whether a pack at [packVersion] with [detectorId] and [classifierId]
/// has newer models than the ones that made a run at [runPackVersion] with
/// [runDetectorId] and [runClassifierId]: a later pack whose detector (and
/// with it the video tracker) or naming model differs. A later pack with
/// the same models only renames, which needs the embeddings that only the
/// device that made the run holds.
bool hasNewerModels({
  required String packVersion,
  required String detectorId,
  required String classifierId,
  required String runPackVersion,
  required String runDetectorId,
  required String runClassifierId,
}) =>
    comparePackVersions(packVersion, runPackVersion) > 0 &&
    (detectorId != runDetectorId || classifierId != runClassifierId);
