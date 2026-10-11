import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';

/// What DiveMate's free-text visibility column said: a level, a distance,
/// or text neither reads as.
typedef DiveMateVisibility = ({
  Visibility? level,
  double? meters,
  String? text,
});

/// Reads DiveMate's codes and free-text columns into Submersion's values
/// (#3110).
///
/// The codes were settled against a real DiveMate 5.0 logbook and DiveMate's
/// own exports of it; the spec 2026-10-11-divemate-ddb-import-design.md
/// lists the evidence for each. Everything returns null for a value it
/// cannot read, so the importer leaves the field unset rather than storing a
/// guess. DiveMate writes its text in the app's language, so German and
/// English words are both read.
abstract final class DiveMateValues {
  /// `Water` on a dive or a place: 1 salt, 2 fresh, 0 unset.
  static WaterType? waterType(int? code) => switch (code) {
    1 => WaterType.salt,
    2 => WaterType.fresh,
    _ => null,
  };

  /// `Entry`: 1 shore, 2 boat, 0 unset.
  static EntryMethod? entryMethod(int? code) => switch (code) {
    1 => EntryMethod.shore,
    2 => EntryMethod.boat,
    _ => null,
  };

  /// `Rating`, 1 to 5 stars; 0 is unrated.
  static int? rating(int? stars) =>
      stars != null && stars >= 1 && stars <= 5 ? stars : null;

  static final _distance = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s*(m|meter|metre|meters|metres|ft|feet)?$',
  );

  /// `VisHor`, free text: a level word, a distance, or anything else.
  static DiveMateVisibility visibility(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) {
      return (level: null, meters: null, text: null);
    }
    final level = switch (text.toLowerCase()) {
      'sehr gut' || 'excellent' || 'very good' => Visibility.excellent,
      'gut' || 'good' => Visibility.good,
      'mittel' || 'mäßig' || 'moderate' || 'medium' => Visibility.moderate,
      'schlecht' || 'poor' || 'bad' => Visibility.poor,
      _ => null,
    };
    if (level != null) return (level: level, meters: null, text: text);
    final match = _distance.firstMatch(text.toLowerCase());
    final value = match == null
        ? null
        : double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value != null && value > 0) {
      final unit = match!.group(2);
      final meters = unit != null && unit.startsWith('f')
          ? DepthUnit.feet.convert(value, DepthUnit.meters)
          : value;
      return (level: null, meters: meters, text: text);
    }
    return (level: null, meters: null, text: text);
  }

  /// `UWCurrent`, free text such as `leichte Strömung`.
  ///
  /// Matched on the word for the strength, since DiveMate's picker writes the
  /// strength followed by the word for current.
  static CurrentStrength? current(String? raw) {
    final text = raw?.trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text.startsWith('kein') || text == 'none' || text == 'no current') {
      return CurrentStrength.none;
    }
    if (text.startsWith('leicht') ||
        text.startsWith('light') ||
        text.startsWith('weak') ||
        text.startsWith('schwach')) {
      return CurrentStrength.light;
    }
    if (text.startsWith('mittl') ||
        text.startsWith('mittel') ||
        text.startsWith('moderate') ||
        text.startsWith('medium')) {
      return CurrentStrength.moderate;
    }
    if (text.startsWith('stark') || text.startsWith('strong')) {
      return CurrentStrength.strong;
    }
    return null;
  }

  static final _hoursMinutes = RegExp(r'^(\d+):(\d{2})$');

  /// `Surfint`, `H:MM`. DiveMate writes `0:0-1` when it does not know the
  /// interval and `0:00` for a first dive, so neither is an interval.
  static Duration? surfaceInterval(String? raw) {
    final match = _hoursMinutes.firstMatch(raw?.trim() ?? '');
    if (match == null) return null;
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    if (minutes >= 60) return null;
    final interval = Duration(hours: hours, minutes: minutes);
    return interval > Duration.zero ? interval : null;
  }

  /// `Tank.Tanktype`, and `Val3` on cylinder gear: 1 aluminium, 2 steel.
  /// 0 is unset and 3, seen on default 15 l cylinders, is not settled.
  static TankMaterial? tankMaterial(int? code) => switch (code) {
    1 => TankMaterial.aluminum,
    2 => TankMaterial.steel,
    _ => null,
  };

  /// The cylinder's role from `Tank.DivePhase` (3 deco, 4 stage) and then
  /// `Tank.SupplyType` (4 sidemount).
  ///
  /// DiveMate records that a cylinder is sidemount but not on which side.
  /// [sidemountIndex] is its position among the dive's sidemount cylinders,
  /// in DiveMate's F1, F2 order; the first is taken as left and the rest as
  /// right, the convention the diver can swap per dive.
  static TankRole tankRole({
    required int? divePhase,
    required int? supplyType,
    required int sidemountIndex,
  }) {
    if (divePhase == 3) return TankRole.deco;
    if (divePhase == 4) return TankRole.stage;
    if (supplyType == 4) {
      return sidemountIndex == 0
          ? TankRole.sidemountLeft
          : TankRole.sidemountRight;
    }
    return TankRole.backGas;
  }

  /// `Equipment.TypeID`, where DiveMate fixed the item's kind: 11 cylinder,
  /// 12 weight, 17 dive computer. 0 means the category says.
  static EquipmentType? equipmentTypeFromCode(int? code) => switch (code) {
    11 => EquipmentType.tank,
    12 => EquipmentType.weights,
    17 => EquipmentType.computer,
    _ => null,
  };

  /// `Equipment.Category`, the diver's own category name.
  static EquipmentType? equipmentTypeFromCategory(String? category) =>
      switch (category?.trim().toLowerCase()) {
        'flaschen' ||
        'flasche' ||
        'tanks' ||
        'tank' ||
        'cylinders' => EquipmentType.tank,
        'blei' || 'weights' || 'weight' => EquipmentType.weights,
        'tauchcomputer' ||
        'computer' ||
        'dive computer' => EquipmentType.computer,
        'wing' || 'wings' => EquipmentType.wing,
        'jacket' || 'tarierjacket' || 'bcd' => EquipmentType.bcd,
        'flossen' || 'fins' => EquipmentType.fins,
        'maske' || 'masken' || 'mask' => EquipmentType.mask,
        'atemregler' ||
        'regler' ||
        'regulator' ||
        'regulators' => EquipmentType.regulator,
        'lampe' || 'lampen' || 'light' || 'lights' => EquipmentType.light,
        'kamera' || 'camera' => EquipmentType.camera,
        'schnorchel' || 'snorkel' => EquipmentType.snorkel,
        'kompass' || 'compass' => EquipmentType.compass,
        'boje' || 'smb' => EquipmentType.smb,
        _ => null,
      };

  /// Whether [category] holds suits, whose kind only the name tells.
  static bool isSuitCategory(String? category) =>
      switch (category?.trim().toLowerCase()) {
        'anzug' ||
        'anzüge' ||
        'tauchanzug' ||
        'tauchanzüge' ||
        'suits' ||
        'suit' => true,
        _ => false,
      };

  /// The kind of suit a German name gives: `Trocki` is a drysuit, `Nass`,
  /// `Neo` and `Shorty` wetsuits, `Lycra` a rash guard. Null when the name
  /// says none of these, so the general name reader can try.
  static EquipmentType? suitFromName(String name) {
    final lower = name.toLowerCase();
    // Semi-dry first: `halbtrocken` contains `trocken` but is a wetsuit.
    if (lower.contains('halbtrocken') ||
        lower.contains('nass') ||
        lower.contains('neo') ||
        lower.contains('shorty')) {
      return EquipmentType.wetsuit;
    }
    if (lower.contains('trocki') || lower.contains('trocken')) {
      return EquipmentType.drysuit;
    }
    if (lower.contains('lycra')) return EquipmentType.rashGuard;
    return null;
  }
}
