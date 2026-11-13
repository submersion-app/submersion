import 'dart:convert';

/// An activity file on a Garmin watch, as far as [GarminActivityMarker]
/// needs to know it.
class GarminActivityFile {
  const GarminActivityFile({required this.name, this.modifiedMillis});

  /// The file name, such as "2026-11-01-10-22-31.fit".
  final String name;

  /// Last-modified time in milliseconds since the epoch, if known.
  final int? modifiedMillis;
}

/// The newest activity a Garmin download has handled (issue #4223), so the
/// next download reads only the files after it: those the diver imported,
/// skipped or found already logged are not offered again.
///
/// Garmin names an activity file after its start time
/// (`YYYY-MM-DD-hh-mm-ss.fit`), which orders files reliably. A file named any
/// other way is placed by its modified time, and a file that cannot be placed
/// at all is kept, so the marker never hides a new dive.
///
/// Stored in the computer's `lastDiveFingerprint`, which a Garmin never
/// otherwise uses, so it syncs and merges like a download cursor.
class GarminActivityMarker {
  const GarminActivityMarker({this.name, this.modifiedMillis});

  /// The newest date-named file, lower-cased; null when none was date-named.
  final String? name;

  /// The newest modified time among the files.
  final int? modifiedMillis;

  static const _prefix = 'garmin-fit:';

  static final _dateName = RegExp(
    r'^\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}\.fit$',
    caseSensitive: false,
  );

  static bool _isDateNamed(String name) => _dateName.hasMatch(name);

  /// The marker just past every file in [files]; null when none of them can
  /// be placed.
  static GarminActivityMarker? newest(Iterable<GarminActivityFile> files) {
    String? name;
    int? modified;
    for (final file in files) {
      final lower = file.name.toLowerCase();
      if (_isDateNamed(lower) && (name == null || lower.compareTo(name) > 0)) {
        name = lower;
      }
      final time = file.modifiedMillis;
      if (time != null && (modified == null || time > modified)) {
        modified = time;
      }
    }
    if (name == null && modified == null) return null;
    return GarminActivityMarker(name: name, modifiedMillis: modified);
  }

  /// True when [file] came after this marker, or cannot be placed against it.
  bool isBefore(GarminActivityFile file) {
    final lower = file.name.toLowerCase();
    final markerName = name;
    if (markerName != null && _isDateNamed(lower)) {
      return lower.compareTo(markerName) > 0;
    }
    final markerTime = modifiedMillis;
    final fileTime = file.modifiedMillis;
    if (markerTime != null && fileTime != null) return fileTime > markerTime;
    return true;
  }

  /// The later of this marker and [other], part by part.
  GarminActivityMarker laterOf(GarminActivityMarker? other) {
    if (other == null) return this;
    String? laterName = name;
    final otherName = other.name;
    if (otherName != null &&
        (laterName == null || otherName.compareTo(laterName) > 0)) {
      laterName = otherName;
    }
    int? laterTime = modifiedMillis;
    final otherTime = other.modifiedMillis;
    if (otherTime != null && (laterTime == null || otherTime > laterTime)) {
      laterTime = otherTime;
    }
    return GarminActivityMarker(name: laterName, modifiedMillis: laterTime);
  }

  String toFingerprint() =>
      '$_prefix${jsonEncode({if (name != null) 'name': name, if (modifiedMillis != null) 'modified': modifiedMillis})}';

  /// The marker stored as [fingerprint]; null for anything else, such as a
  /// libdivecomputer fingerprint.
  static GarminActivityMarker? fromFingerprint(String? fingerprint) {
    if (fingerprint == null || !fingerprint.startsWith(_prefix)) return null;
    try {
      final decoded = jsonDecode(fingerprint.substring(_prefix.length));
      if (decoded is! Map<String, dynamic>) return null;
      final name = decoded['name'];
      final modified = decoded['modified'];
      final marker = GarminActivityMarker(
        name: name is String ? name.toLowerCase() : null,
        modifiedMillis: modified is int ? modified : null,
      );
      if (marker.name == null && marker.modifiedMillis == null) return null;
      return marker;
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GarminActivityMarker &&
      other.name == name &&
      other.modifiedMillis == modifiedMillis;

  @override
  int get hashCode => Object.hash(name, modifiedMillis);

  @override
  String toString() => toFingerprint();
}
