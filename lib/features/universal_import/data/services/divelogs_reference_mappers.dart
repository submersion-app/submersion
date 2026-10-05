import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';

/// Pure lookup tables between divelogs.de reference data (geartype names,
/// certification orgs) and Submersion's domain enums. Geartype names carry
/// German synonyms (divelogs.de's home locale) alongside English.
abstract final class DivelogsReferenceMappers {
  /// Keyword table, first match wins. Drysuit keywords come before the
  /// generic suit keywords so "Trockentauchanzug"/"Drysuit" do not fall
  /// into wetsuit.
  static const List<(List<String>, EquipmentType)> _leadingKeywords = [
    (['regulator', 'lungenautomat', 'atemregler'], EquipmentType.regulator),
    (['bcd', 'jacket', 'wing', 'tarierweste'], EquipmentType.bcd),
    (['drysuit', 'dry suit', 'trocken'], EquipmentType.drysuit),
    (['wetsuit', 'wet suit', 'nass', 'suit', 'anzug'], EquipmentType.wetsuit),
    (['fin', 'flosse'], EquipmentType.fins),
    (['mask', 'maske'], EquipmentType.mask),
    (['computer'], EquipmentType.computer),
    (['tank', 'cylinder', 'flasche'], EquipmentType.tank),
    (['weight', 'blei'], EquipmentType.weights),
  ];

  /// After [_leadingKeywords]: the English camera part words come from
  /// [MacDiveValueMapper.cameraPartType] (#1997), and these rows carry the
  /// German ones, ahead of the light and camera words their names contain
  /// ("Videolampe", "Blitzarm"). A float arm comes before the arms and an
  /// arm before the strobe it carries. "Nasslinse" (a wet lens) cannot be
  /// listed: the wetsuit row's "nass" claims it first.
  static const List<(List<String>, EquipmentType)> _geartypeKeywords = [
    (['auftriebsarm'], EquipmentType.floatArm),
    (['blitzarm', 'klemme'], EquipmentType.armClamp),
    (['kameraschiene', 'pistolengriff'], EquipmentType.trayHandle),
    (['videolicht', 'videolampe'], EquipmentType.videoLight),
    (['domeport', 'makroport'], EquipmentType.port),
    (['objektiv', 'dioptrie'], EquipmentType.lens),
    (['housing', 'gehäuse'], EquipmentType.housing),
    (['strobe', 'blitz'], EquipmentType.strobe),
    (['light', 'lamp', 'lampe'], EquipmentType.light),
    (['camera', 'kamera'], EquipmentType.camera),
    (['boot', 'füßling', 'fussling'], EquipmentType.boots),
    (['glove', 'handschuh'], EquipmentType.gloves),
    (['hood', 'haube'], EquipmentType.hood),
    (['knife', 'messer'], EquipmentType.knife),
    (['reel'], EquipmentType.reel),
    (['smb', 'boje', 'hebesack'], EquipmentType.smb),
    // Last (#2952): "Tasche" also names a pocket, so a lead pouch
    // ("Bleitasche") or a light's pouch is claimed by its item word first.
    (['bag', 'tasche', 'luggage'], EquipmentType.bag),
  ];

  static EquipmentType equipmentTypeForGeartypeName(String? name) {
    if (name == null) return EquipmentType.other;
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return EquipmentType.other;
    // Lift and breathing bags (#2952) are read by the MacDive reader's own
    // patterns, ahead of the bag row, so every spelling it accepts agrees
    // here: a lift device and a rebreather counterlung, not luggage.
    if (MacDiveValueMapper.liftBag.hasMatch(lower)) return EquipmentType.smb;
    if (MacDiveValueMapper.breathingBag.hasMatch(lower)) {
      return EquipmentType.other;
    }
    for (final (keywords, type) in _leadingKeywords) {
      if (keywords.any(lower.contains)) return type;
    }
    final cameraPart = MacDiveValueMapper.cameraPartType(lower);
    if (cameraPart != null) return cameraPart;
    for (final (keywords, type) in _geartypeKeywords) {
      if (keywords.any(lower.contains)) return type;
    }
    return EquipmentType.other;
  }

  static CertificationAgency agencyForOrg(String? org) {
    if (org == null) return CertificationAgency.other;
    final lower = org.trim().toLowerCase();
    if (lower.isEmpty) return CertificationAgency.other;
    for (final agency in CertificationAgency.values) {
      if (agency.name.toLowerCase() == lower ||
          agency.displayName.toLowerCase() == lower) {
        return agency;
      }
    }
    return CertificationAgency.other;
  }

  /// Matches a remote certification name onto a known level, or null.
  /// The original text stays in the certification's name field either way.
  static CertificationLevel? levelForName(String name) {
    final lower = name.trim().toLowerCase();
    for (final level in CertificationLevel.values) {
      if (level != CertificationLevel.other &&
          level.displayName.toLowerCase() == lower) {
        return level;
      }
    }
    return null;
  }
}
