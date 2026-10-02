/// The two kinds of track the Tracks area lists together.
enum TrackKind { gps, underwater }

/// The Tracks page's kind filter; [all] shows both kinds.
enum TrackKindFilter {
  all,
  gps,
  underwater;

  /// Reads a `?kind=` query value. Null for an absent or unknown value, so
  /// a link without a usable kind leaves the current filter alone.
  static TrackKindFilter? fromQuery(String? value) => switch (value) {
    'all' => TrackKindFilter.all,
    'gps' => TrackKindFilter.gps,
    'underwater' => TrackKindFilter.underwater,
    _ => null,
  };

  bool admits(TrackKind kind) => switch (this) {
    TrackKindFilter.all => true,
    TrackKindFilter.gps => kind == TrackKind.gps,
    TrackKindFilter.underwater => kind == TrackKind.underwater,
  };
}
