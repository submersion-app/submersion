/// When a species tag the app applied logs the dive's sighting of that
/// species (issue #4727). A per-device preference.
enum SightingTiming {
  /// Only once the diver confirms the tag: counts, firsts and statistics
  /// never include the app's unconfirmed guesses. The default.
  onConfirm,

  /// As soon as the app applies the tag. Rejecting the tag later removes
  /// the sighting it created, when nothing else uses it.
  straightAway;

  /// The stored name, or [onConfirm] for anything unknown.
  static SightingTiming fromName(String? name) =>
      SightingTiming.values.firstWhere(
        (t) => t.name == name,
        orElse: () => SightingTiming.onConfirm,
      );
}
