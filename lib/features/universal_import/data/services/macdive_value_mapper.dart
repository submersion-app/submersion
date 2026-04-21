import 'package:submersion/core/constants/enums.dart';

/// Static mappings from MacDive's raw XML string values to Submersion's
/// typed domain enums. Used by the MacDive XML parser and will also be
/// used by the MacDive SQLite parser (Milestone 3).
///
/// Mapping strategy: case-insensitive, substring-based. Unknown or empty
/// input returns null so the importer can omit the field rather than
/// write a default that misrepresents the data.
class MacDiveValueMapper {
  const MacDiveValueMapper._();

  static WaterType? waterType(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;
    if (s.contains('salt') || s == 'sea' || s == 'ocean') {
      return WaterType.salt;
    }
    if (s.contains('fresh') || s == 'lake' || s == 'river' || s == 'quarry') {
      return WaterType.fresh;
    }
    if (s.contains('brackish')) {
      return WaterType.brackish;
    }
    return null;
  }

  static EntryMethod? entryType(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;

    if (s == 'shore' || s == 'beach') {
      return EntryMethod.shore;
    }
    if (s.contains('boat') || s.contains('liveaboard')) {
      return EntryMethod.boat;
    }
    if (s.contains('back') && s.contains('roll')) {
      return EntryMethod.backRoll;
    }
    if (s.contains('giant') && s.contains('stride')) {
      return EntryMethod.giantStride;
    }
    if (s.contains('seated')) {
      return EntryMethod.seatedEntry;
    }
    if (s == 'ladder') {
      return EntryMethod.ladder;
    }
    if (s == 'platform') {
      return EntryMethod.platform;
    }
    if (s.contains('jetty') || s.contains('dock')) {
      return EntryMethod.jetty;
    }

    return null;
  }

  /// Maps a MacDive 0.0-5.0 rating to an integer 0-5. Clamps out-of-range
  /// values. Returns null for null input.
  static int? rating(double? raw) {
    if (raw == null) return null;
    return raw.clamp(0.0, 5.0).round();
  }

  /// Normalizes a MacDive dive-type string to a trimmed canonical form.
  /// MacDive uses arbitrary dive-type labels; Submersion doesn't constrain
  /// to an enum. Callers who need to create DiveTypes entities pass the
  /// result as a tag name.
  static String normalizeDiveType(String raw) => raw.trim();
}
