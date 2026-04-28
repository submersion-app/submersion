/// Supported manifest container formats.
///
/// Atom and RSS are folded together because the `AtomManifestParser` is
/// tolerant of mixed roots in the wild.
enum ManifestFormat {
  atom,
  json,
  csv;

  String get displayName {
    switch (this) {
      case ManifestFormat.atom:
        return 'Atom / RSS';
      case ManifestFormat.json:
        return 'JSON';
      case ManifestFormat.csv:
        return 'CSV';
    }
  }

  static ManifestFormat? fromString(String? value) {
    if (value == null) return null;
    for (final f in ManifestFormat.values) {
      if (f.name == value) return f;
    }
    return null;
  }
}
