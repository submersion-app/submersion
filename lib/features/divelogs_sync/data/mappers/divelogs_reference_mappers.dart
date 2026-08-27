import 'package:submersion/core/constants/enums.dart';

/// Pure lookup tables between divelogs.de reference data (geartype names,
/// certification orgs) and Submersion's domain enums. Geartype names carry
/// German synonyms — divelogs.de's home locale — alongside English.
abstract final class DivelogsReferenceMappers {
  /// Keyword table, first match wins. Drysuit keywords come before the
  /// generic suit keywords so "Trockentauchanzug"/"Drysuit" do not fall
  /// into wetsuit.
  static const List<(List<String>, EquipmentType)> _geartypeKeywords = [
    (['regulator', 'lungenautomat', 'atemregler'], EquipmentType.regulator),
    (['bcd', 'jacket', 'wing', 'tarierweste'], EquipmentType.bcd),
    (['drysuit', 'dry suit', 'trocken'], EquipmentType.drysuit),
    (['wetsuit', 'wet suit', 'nass', 'suit', 'anzug'], EquipmentType.wetsuit),
    (['fin', 'flosse'], EquipmentType.fins),
    (['mask', 'maske'], EquipmentType.mask),
    (['computer'], EquipmentType.computer),
    (['tank', 'cylinder', 'flasche'], EquipmentType.tank),
    (['weight', 'blei'], EquipmentType.weights),
    (['light', 'lamp', 'lampe'], EquipmentType.light),
    (['camera', 'kamera'], EquipmentType.camera),
    (['boot', 'füßling', 'fussling'], EquipmentType.boots),
    (['glove', 'handschuh'], EquipmentType.gloves),
    (['hood', 'haube'], EquipmentType.hood),
    (['knife', 'messer'], EquipmentType.knife),
    (['reel'], EquipmentType.reel),
    (['smb', 'boje'], EquipmentType.smb),
  ];

  static EquipmentType equipmentTypeForGeartypeName(String? name) {
    if (name == null) return EquipmentType.other;
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return EquipmentType.other;
    for (final (keywords, type) in _geartypeKeywords) {
      if (keywords.any(lower.contains)) return type;
    }
    return EquipmentType.other;
  }

  /// First remote geartype id whose name maps to [type], or null.
  static int? geartypeIdForEquipmentType(
    EquipmentType type,
    Map<int, String> geartypes,
  ) {
    for (final entry in geartypes.entries) {
      if (equipmentTypeForGeartypeName(entry.value) == type) {
        return entry.key;
      }
    }
    return null;
  }

  /// First remote geartype name that maps to [type], or null.
  static String? geartypeNameForEquipmentType(
    EquipmentType type,
    Map<int, String> geartypes,
  ) {
    final id = geartypeIdForEquipmentType(type, geartypes);
    return id == null ? null : geartypes[id];
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
