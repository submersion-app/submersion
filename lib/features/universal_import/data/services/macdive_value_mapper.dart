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

  /// Maps MacDive's free-text equipment type onto [EquipmentType].
  ///
  /// MacDive lets the diver type anything into the field, so real libraries
  /// contain values like "BCD - Wing", "Reg - Longhose" and "Octopus" that do
  /// not match an enum name. Without this, `_parseEquipmentType` fell through
  /// to [EquipmentType.other] for nearly every imported item.
  ///
  /// Returns null for empty input so the importer keeps its own default.
  static EquipmentType? equipmentType(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;

    // Ordered longest-idea-first: "drysuit" must beat "suit", and the
    // regulator family must not swallow "octopus", which is its own type in
    // neither vocabulary but reads as a regulator to divers.
    if (s.contains('drysuit') || s.contains('dry suit')) {
      return EquipmentType.drysuit;
    }
    if (s.contains('wetsuit') || s.contains('wet suit')) {
      return EquipmentType.wetsuit;
    }
    if (s.contains('rebreather') || s.contains('ccr') || s.contains('scr')) {
      return EquipmentType.rebreather;
    }
    // Before the light/camera family: a scooter is often logged by brand and
    // model with "DPV" or "Scooter" as the only generic word in the label.
    if (s.contains('dpv') ||
        s.contains('scooter') ||
        s.contains('propulsion')) {
      return EquipmentType.dpv;
    }
    if (s.contains('transmitter') || s.contains('ai ')) {
      return EquipmentType.transmitter;
    }
    if (s.contains('computer') || s.contains('watch')) {
      return EquipmentType.computer;
    }
    if (s.contains('octo') ||
        s.contains('regulator') ||
        s.startsWith('reg') ||
        s.contains('second stage') ||
        s.contains('first stage')) {
      return EquipmentType.regulator;
    }
    if (s.contains('bcd') ||
        s.contains('bc ') ||
        s == 'bc' ||
        s.contains('wing') ||
        s.contains('harness') ||
        s.contains('backplate')) {
      return EquipmentType.bcd;
    }
    if (s.contains('tank') || s.contains('cylinder')) return EquipmentType.tank;
    if (s.contains('weight') || s.contains('ballast')) {
      return EquipmentType.weights;
    }
    if (s.contains('fin')) return EquipmentType.fins;
    if (s.contains('mask') || s.contains('goggle')) return EquipmentType.mask;
    if (s.contains('hood')) return EquipmentType.hood;
    if (s.contains('glove') || s.contains('mitt')) return EquipmentType.gloves;
    if (s.contains('boot') || s.contains('bootie')) return EquipmentType.boots;
    if (s.contains('light') || s.contains('torch')) return EquipmentType.light;
    if (s.contains('camera') ||
        s.contains('housing') ||
        s.contains('strobe') ||
        s.contains('gopro')) {
      return EquipmentType.camera;
    }
    if (s.contains('smb') ||
        s.contains('dsmb') ||
        s.contains('buoy') ||
        s.contains('sausage')) {
      return EquipmentType.smb;
    }
    if (s.contains('reel') || s.contains('spool')) return EquipmentType.reel;
    if (s.contains('knife') || s.contains('shear') || s.contains('cutter')) {
      return EquipmentType.knife;
    }
    return EquipmentType.other;
  }
}
