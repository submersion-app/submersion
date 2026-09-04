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
///
/// Every dimension stores its canonical metric value, which for all of them
/// except the two per-time ones is also what a metric diver reads:
/// - [speedMps] stores m/s (matching wind speed and GPS track speed) and
///   displays as m/min or ft/min, the way a DPV's rated speed is quoted.
/// - [durationH] stores hours and displays as minutes, the way a scooter's
///   rated run time is quoted.
enum AttributeDimension {
  none,
  thicknessMm,
  volumeL,
  pressureBar,
  massKg,
  lengthM,
  depthM,
  speedMps,
  durationH,
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
  static const weightStyle = 'weight_style';
  static const insulationLevel = 'insulation_level';
  static const fillMaterial = 'fill_material';
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

  /// How a wrist-or-console device is carried. Shared by the dive computer,
  /// the instrument family and the compass: one key, one set of translations,
  /// no chance of the three drifting apart per locale.
  static const _mount = EquipmentAttributeDef(
    key: 'mount',
    kind: AttributeKind.choice,
    choiceKeys: ['wrist', 'console', 'hud'],
  );

  /// How warm the garment is, in the four steps drysuit makers actually
  /// print on a label. Undergarments are sold by warmth rating rather than by
  /// millimetres, so [EquipmentAttrKeys.thicknessMm] would be the wrong
  /// question: a 400g Thinsulate suit and a fleece of the same loft are not
  /// the same garment.
  static const _insulationLevel = EquipmentAttributeDef(
    key: EquipmentAttrKeys.insulationLevel,
    kind: AttributeKind.choice,
    choiceKeys: ['light', 'mid', 'heavy', 'extreme'],
  );

  /// What the garment is made of. Shared by both layers: the same fibres show
  /// up in undersuits and in the base layers worn beneath them.
  static const _fillMaterial = EquipmentAttributeDef(
    key: EquipmentAttrKeys.fillMaterial,
    kind: AttributeKind.choice,
    choiceKeys: [
      'thinsulate',
      'primaloft',
      'hollowfibre',
      'fleece',
      'merino',
      'polypropylene',
    ],
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
    EquipmentType.undersuit: [_size, _insulationLevel, _fillMaterial],
    EquipmentType.baselayer: [_size, _insulationLevel, _fillMaterial],
    // Warmth is deliberately absent: that is what `baselayer` is for, and a
    // second way to say "this one is warm" is how two keys for one idea drift
    // apart per locale. A rash guard is the sun-and-abrasion garment.
    EquipmentType.rashGuard: [
      _size,
      EquipmentAttributeDef(
        key: 'sleeve_length',
        kind: AttributeKind.choice,
        choiceKeys: ['short', 'long', 'sleeveless'],
      ),
      // The rating printed on the garment (UPF 50+ is the common ceiling).
      // Dimensionless: a UPF number is a ratio, not a measurement.
      EquipmentAttributeDef(key: 'upf_rating', kind: AttributeKind.number),
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
    EquipmentType.rebreather: [
      EquipmentAttributeDef(
        key: 'unit_type',
        kind: AttributeKind.choice,
        choiceKeys: [
          'eccr',
          'mccr',
          'hccr',
          'scr_cmf',
          'scr_pascr',
          'scr_escr',
        ],
      ),
      EquipmentAttributeDef(
        key: 'mount_configuration',
        kind: AttributeKind.choice,
        choiceKeys: ['back', 'chest', 'sidemount'],
      ),
      EquipmentAttributeDef(
        key: 'scrubber_type',
        kind: AttributeKind.choice,
        choiceKeys: ['axial', 'radial'],
      ),
      // Rated scrubber duration in hours. Dimensionless: hours are hours in
      // every market, so there is nothing for UnitFormatter to convert.
      EquipmentAttributeDef(
        key: 'scrubber_duration_h',
        kind: AttributeKind.number,
      ),
      EquipmentAttributeDef(key: 'o2_cell_count', kind: AttributeKind.number),
      EquipmentAttributeDef(
        key: 'diluent_cylinder_l',
        kind: AttributeKind.number,
        dimension: AttributeDimension.volumeL,
      ),
      EquipmentAttributeDef(
        key: 'o2_cylinder_l',
        kind: AttributeKind.number,
        dimension: AttributeDimension.volumeL,
      ),
      // Shared verbatim with the camera entry: same concept, same dimension,
      // one label key.
      EquipmentAttributeDef(
        key: 'depth_rating_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.depthM,
      ),
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
      _mount,
      EquipmentAttributeDef(
        key: 'connectivity',
        kind: AttributeKind.choice,
        choiceKeys: ['ble', 'usb', 'infrared', 'none'],
      ),
    ],
    EquipmentType.instrument: [
      EquipmentAttributeDef(
        key: 'instrument_type',
        kind: AttributeKind.choice,
        choiceKeys: [
          'spg',
          'depth_gauge',
          'bottom_timer',
          'console',
          'gas_analyzer',
          'thermometer',
        ],
      ),
      // Full-scale reading of the dial, not a tank's working pressure: a
      // 300 bar gauge on a 232 bar cylinder is a different object from a
      // 232 bar one, and the two keys must not be confused.
      EquipmentAttributeDef(
        key: 'gauge_max_pressure_bar',
        kind: AttributeKind.number,
        dimension: AttributeDimension.pressureBar,
      ),
      // Shared verbatim with the camera, rebreather and DPV entries.
      EquipmentAttributeDef(
        key: 'depth_rating_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.depthM,
      ),
      _mount,
    ],
    EquipmentType.compass: [
      EquipmentAttributeDef(
        key: 'compass_type',
        kind: AttributeKind.choice,
        choiceKeys: ['analog', 'digital'],
      ),
      // A card is balanced for a magnetic zone; take a northern-balanced
      // compass south and it drags on the capsule and reads badly. Worth
      // recording per unit for anyone whose gear travels.
      EquipmentAttributeDef(
        key: 'balance_zone',
        kind: AttributeKind.choice,
        choiceKeys: ['northern', 'southern', 'global'],
      ),
      // Degrees of off-level the card still swings freely at: the headline
      // spec on every dive compass, and degrees convert nowhere.
      EquipmentAttributeDef(
        key: 'tilt_tolerance_deg',
        kind: AttributeKind.number,
      ),
      _mount,
    ],
    EquipmentType.mask: [
      EquipmentAttributeDef(
        key: 'lens_config',
        kind: AttributeKind.choice,
        choiceKeys: ['single', 'twin', 'frameless'],
      ),
      EquipmentAttributeDef(key: 'prescription', kind: AttributeKind.flag),
    ],
    EquipmentType.snorkel: [
      EquipmentAttributeDef(
        key: 'snorkel_type',
        kind: AttributeKind.choice,
        choiceKeys: ['classic', 'semi_dry', 'dry', 'foldable'],
      ),
      EquipmentAttributeDef(key: 'purge_valve', kind: AttributeKind.flag),
    ],
    EquipmentType.weights: [
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.weightStyle,
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
    EquipmentType.dpv: [
      EquipmentAttributeDef(
        key: 'dpv_style',
        kind: AttributeKind.choice,
        choiceKeys: ['tow_behind', 'ride_on', 'handheld'],
      ),
      // Rated run time. Stored in hours (hence the key), but shown in minutes
      // because that is how every scooter's burn time is specced -- "90 min",
      // not "1.5 h" (issue #1096). The rebreather's scrubber duration keeps
      // hours: those are quoted as "3 h", not "180 min".
      EquipmentAttributeDef(
        key: 'burn_time_h',
        kind: AttributeKind.number,
        dimension: AttributeDimension.durationH,
      ),
      EquipmentAttributeDef(
        key: 'battery_type',
        kind: AttributeKind.choice,
        choiceKeys: ['lithium_ion', 'nimh', 'lead_acid'],
      ),
      // Watt-hours: the figure printed on the pack and the one airlines ask
      // about, universal in every market.
      EquipmentAttributeDef(
        key: 'battery_capacity_wh',
        kind: AttributeKind.number,
      ),
      EquipmentAttributeDef(
        key: 'motor_type',
        kind: AttributeKind.choice,
        choiceKeys: ['brushless', 'brushed'],
      ),
      // Stored in m/s, read as m/min or ft/min: a DPV's speed is quoted per
      // minute on every manufacturer's sheet, never in km/h or knots.
      EquipmentAttributeDef(
        key: 'speed_mps',
        kind: AttributeKind.number,
        dimension: AttributeDimension.speedMps,
      ),
      // Shared verbatim with the camera and rebreather entries.
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
    EquipmentType.tool: [
      EquipmentAttributeDef(
        key: 'tool_type',
        kind: AttributeKind.choice,
        choiceKeys: [
          'hand_tool',
          'o_ring_kit',
          'save_a_dive_kit',
          'torque_wrench',
          'spares_kit',
        ],
      ),
      // Free text because a tool's size is a spanner width, a hex key, or
      // nothing at all -- there is no closed list to pick from.
      _size,
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
