import 'package:submersion/core/constants/enums.dart';

/// How an attribute value is entered, stored, and displayed.
/// Storage contract (equipment_attributes row):
/// - text:      valueText
/// - number:    valueNum in canonical metric (see AttributeDimension)
/// - thickness: valueText holds the designation as written ("5/4/3"),
///              valueNum holds the parsed primary (thickest) panel in mm
/// - choice:    valueText holds the stable option key (never a display string)
/// - flag:      valueNum 0/1
/// - date:      valueNum unix milliseconds
enum AttributeKind { text, number, thickness, choice, flag, date }

/// Unit dimension for number attributes; drives UnitFormatter conversion.
/// thicknessMm always displays in mm (industry convention in every market).
enum AttributeDimension {
  none,
  thicknessMm,
  volumeL,
  pressureBar,
  massKg,
  lengthM,
  depthM,
}

/// Stable attribute keys referenced from more than one file.
abstract final class EquipmentAttrKeys {
  static const size = 'size';
  static const thicknessMm = 'thickness_mm';
  static const buoyancyKg = 'buoyancy_kg';
  static const dryWeightKg = 'dry_weight_kg';
  static const suitStyle = 'suit_style';
  static const shellMaterial = 'shell_material';
  static const bcdStyle = 'bcd_style';
  static const liftCapacityKg = 'lift_capacity_kg';
  static const gloveType = 'glove_type';
}

class EquipmentAttributeDef {
  /// Stable key, never translated ('thickness_mm'). L10n resolves labels via
  /// `attrLabel_<key>` and choice options via `attrChoice_<key>_<option>`.
  final String key;
  final AttributeKind kind;
  final AttributeDimension dimension;
  final List<String> choiceKeys;

  const EquipmentAttributeDef({
    required this.key,
    required this.kind,
    this.dimension = AttributeDimension.none,
    this.choiceKeys = const [],
  });
}

/// Data-driven per-type attribute schema (CertificationLevelCatalog pattern).
abstract final class EquipmentAttributeCatalog {
  /// Present for every equipment type (they replace the v104 columns).
  static const List<EquipmentAttributeDef> universal = [
    EquipmentAttributeDef(
      key: EquipmentAttrKeys.buoyancyKg,
      kind: AttributeKind.number,
      dimension: AttributeDimension.massKg,
    ),
    EquipmentAttributeDef(
      key: EquipmentAttrKeys.dryWeightKg,
      kind: AttributeKind.number,
      dimension: AttributeDimension.massKg,
    ),
  ];

  static const _size = EquipmentAttributeDef(
    key: EquipmentAttrKeys.size,
    kind: AttributeKind.text,
  );
  static const _thickness = EquipmentAttributeDef(
    key: EquipmentAttrKeys.thicknessMm,
    kind: AttributeKind.thickness,
    dimension: AttributeDimension.thicknessMm,
  );

  static const Map<EquipmentType, List<EquipmentAttributeDef>> _byType = {
    EquipmentType.wetsuit: [
      _size,
      _thickness,
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.suitStyle,
        kind: AttributeKind.choice,
        choiceKeys: ['full', 'shorty', 'two_piece', 'semi_dry'],
      ),
    ],
    EquipmentType.drysuit: [
      _size,
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.shellMaterial,
        kind: AttributeKind.choice,
        choiceKeys: [
          'trilaminate',
          'neoprene',
          'crushed_neoprene',
          'vulcanized_rubber',
        ],
      ),
      EquipmentAttributeDef(
        key: 'seal_type',
        kind: AttributeKind.choice,
        choiceKeys: ['latex', 'silicone', 'neoprene'],
      ),
    ],
    EquipmentType.tank: [
      EquipmentAttributeDef(
        key: 'volume_l',
        kind: AttributeKind.number,
        dimension: AttributeDimension.volumeL,
      ),
      EquipmentAttributeDef(
        key: 'working_pressure_bar',
        kind: AttributeKind.number,
        dimension: AttributeDimension.pressureBar,
      ),
      EquipmentAttributeDef(
        key: 'tank_material',
        kind: AttributeKind.choice,
        choiceKeys: ['aluminum', 'steel', 'carbon_composite'],
      ),
      EquipmentAttributeDef(
        key: 'valve_type',
        kind: AttributeKind.choice,
        choiceKeys: ['din', 'yoke', 'convertible'],
      ),
      EquipmentAttributeDef(key: 'tank_identifier', kind: AttributeKind.text),
      EquipmentAttributeDef(
        key: 'last_visual_inspection',
        kind: AttributeKind.date,
      ),
      EquipmentAttributeDef(key: 'last_hydro_test', kind: AttributeKind.date),
    ],
    EquipmentType.regulator: [
      EquipmentAttributeDef(
        key: 'connection',
        kind: AttributeKind.choice,
        choiceKeys: ['din', 'yoke'],
      ),
      EquipmentAttributeDef(key: 'cold_water_rated', kind: AttributeKind.flag),
    ],
    EquipmentType.bcd: [
      _size,
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.bcdStyle,
        kind: AttributeKind.choice,
        choiceKeys: ['jacket', 'back_inflate', 'wing', 'sidemount'],
      ),
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.liftCapacityKg,
        kind: AttributeKind.number,
        dimension: AttributeDimension.massKg,
      ),
    ],
    EquipmentType.fins: [
      _size,
      EquipmentAttributeDef(
        key: 'heel_type',
        kind: AttributeKind.choice,
        choiceKeys: ['open_heel', 'full_foot'],
      ),
      EquipmentAttributeDef(
        key: 'blade_style',
        kind: AttributeKind.choice,
        choiceKeys: ['paddle', 'split', 'vented'],
      ),
    ],
    EquipmentType.computer: [
      EquipmentAttributeDef(
        key: 'mount',
        kind: AttributeKind.choice,
        choiceKeys: ['wrist', 'console', 'hud'],
      ),
      EquipmentAttributeDef(
        key: 'connectivity',
        kind: AttributeKind.choice,
        choiceKeys: ['ble', 'usb', 'infrared', 'none'],
      ),
    ],
    EquipmentType.mask: [
      EquipmentAttributeDef(
        key: 'lens_config',
        kind: AttributeKind.choice,
        choiceKeys: ['single', 'twin', 'frameless'],
      ),
      EquipmentAttributeDef(key: 'prescription', kind: AttributeKind.flag),
    ],
    EquipmentType.weights: [
      EquipmentAttributeDef(
        key: 'weight_style',
        kind: AttributeKind.choice,
        choiceKeys: ['belt', 'integrated', 'trim', 'ankle'],
      ),
    ],
    EquipmentType.light: [
      EquipmentAttributeDef(key: 'lumens', kind: AttributeKind.number),
      EquipmentAttributeDef(
        key: 'beam_type',
        kind: AttributeKind.choice,
        choiceKeys: ['spot', 'flood', 'adjustable'],
      ),
    ],
    EquipmentType.camera: [
      EquipmentAttributeDef(
        key: 'depth_rating_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.depthM,
      ),
    ],
    EquipmentType.smb: [
      EquipmentAttributeDef(
        key: 'smb_type',
        kind: AttributeKind.choice,
        choiceKeys: ['open', 'closed'],
      ),
      EquipmentAttributeDef(
        key: 'length_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.lengthM,
      ),
    ],
    EquipmentType.reel: [
      EquipmentAttributeDef(
        key: 'reel_type',
        kind: AttributeKind.choice,
        choiceKeys: ['spool', 'ratchet'],
      ),
      EquipmentAttributeDef(
        key: 'line_length_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.lengthM,
      ),
    ],
    EquipmentType.knife: [
      EquipmentAttributeDef(
        key: 'blade_material',
        kind: AttributeKind.choice,
        choiceKeys: ['stainless', 'titanium'],
      ),
      EquipmentAttributeDef(
        key: 'tip_type',
        kind: AttributeKind.choice,
        choiceKeys: ['pointed', 'blunt', 'line_cutter'],
      ),
    ],
    EquipmentType.hood: [_size, _thickness],
    EquipmentType.gloves: [
      _size,
      _thickness,
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.gloveType,
        kind: AttributeKind.choice,
        choiceKeys: ['five_finger', 'mitt', 'dry'],
      ),
    ],
    EquipmentType.boots: [
      _size,
      _thickness,
      EquipmentAttributeDef(
        key: 'sole_type',
        kind: AttributeKind.choice,
        choiceKeys: ['hard', 'soft'],
      ),
    ],
    EquipmentType.other: [],
  };

  /// Curated attributes for [type]: type-specific first, then universal.
  static List<EquipmentAttributeDef> attributesFor(EquipmentType type) => [
    ...(_byType[type] ?? const []),
    ...universal,
  ];

  static final Map<String, EquipmentAttributeDef> _byKey = {
    for (final defs in _byType.values)
      for (final def in defs) def.key: def,
    for (final def in universal) def.key: def,
  };

  /// Definition for a curated key, or null for unknown/custom keys.
  static EquipmentAttributeDef? defFor(String key) => _byKey[key];
}

/// Parses the primary (thickest, written-first) panel from a thickness
/// designation: "5" -> 5, "5/4" -> 5, "7/5/3" -> 7, "6mm" -> 6, "thin" -> null.
double? parsePrimaryThickness(String text) {
  final match = RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(text);
  if (match == null) return null;
  return double.parse(match.group(1)!);
}

/// Whether [text] is an acceptable thickness designation for the edit form:
/// one or more numeric panels separated by `/`, `,` or `-`, each optionally
/// suffixed with `mm`. Accepts the legacy values the v124 migration preserves
/// verbatim (e.g. "6mm") and multi-panel forms ("5/4/3"); empty is valid
/// because the field is optional. Only non-numeric garbage ("thin") fails.
bool isValidThicknessDesignation(String text) {
  final t = text.trim();
  if (t.isEmpty) return true;
  return RegExp(
    r'^\d+(?:\.\d+)?\s*(?:mm)?(?:\s*[/,\-]\s*\d+(?:\.\d+)?\s*(?:mm)?)*$',
  ).hasMatch(t);
}
