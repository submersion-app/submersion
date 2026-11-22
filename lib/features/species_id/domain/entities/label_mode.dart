/// What the viewer draws over a photo or video for the animals the app
/// found (issue #4825).
enum LabelMode {
  /// A pill on each animal the app can name or the diver tagged, and the
  /// guarded dot on an unnamed one (a paused video, or a photo).
  names,

  /// The names, and a dot on every other animal found.
  allLife,

  /// Nothing.
  off;

  /// How the mode is stored.
  String get id => name;

  /// The mode stored as [id]. An id this version does not know, or none,
  /// reads as [names].
  static LabelMode fromId(String? id) {
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return names;
  }
}
