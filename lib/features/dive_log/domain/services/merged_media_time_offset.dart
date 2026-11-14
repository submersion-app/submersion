/// The media time shift a dive made from [dives] holds (issue #4539).
///
/// One dive holds one shift, and every dive merged into it hands over its
/// media, which the next placement reads against that shift. So the shift
/// that carries is the one that leaves media already placed where it is: the
/// first of [dives] that owns media keeps its own, zero included, because
/// that zero is what its media is placed by.
///
/// With no media on any of them nothing is placed yet, and the first shift
/// that is set carries, for the media linked later.
///
/// Dives that own media and disagree cannot both be kept: one value cannot
/// stand for two cameras. The first wins and the others' media follows it,
/// which is why [dives] is given in the order the merge already trusts (the
/// target first, or the earliest segment).
int mergedMediaTimeOffsetSeconds(
  Iterable<({String diveId, int offsetSeconds})> dives, {
  required Set<String> diveIdsWithMedia,
}) {
  for (final dive in dives) {
    if (diveIdsWithMedia.contains(dive.diveId)) return dive.offsetSeconds;
  }
  for (final dive in dives) {
    if (dive.offsetSeconds != 0) return dive.offsetSeconds;
  }
  return 0;
}
