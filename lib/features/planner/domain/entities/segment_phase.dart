/// What a leg of a planned profile is doing.
///
/// This is never asked of the diver. It follows from the depths entered and
/// from where the leg sits in the profile, and is resolved by `SegmentChain`.
/// A declared type could contradict the numbers - a segment labelled Descent
/// running 30 m to 12 m was charted and decompressed as an ascent while being
/// billed at the bottom SAC rate - so the geometry is the single source of
/// truth and this exists only for labels, icons and SAC selection.
enum SegmentPhase {
  /// Deeper than where the previous leg left off.
  descent,

  /// Holding depth while the dive is still working: the bottom.
  level,

  /// Holding depth on the way up: a deco or safety stop.
  stop,

  /// Shallower than where the previous leg left off.
  ascent;

  /// Whether the leg holds a constant depth.
  bool get isFlat => this == SegmentPhase.level || this == SegmentPhase.stop;

  /// Whether the leg changes depth.
  bool get isDepthChange => !isFlat;
}
