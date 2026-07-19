import 'package:equatable/equatable.dart';

/// Attribute-derived facts about one equipment item that influence its
/// buoyancy prior. Built by the weight-planner bridge from the equipment
/// attribute store; the buoyancy engine has no knowledge of that store.
///
/// String fields carry the attribute system's stable choice keys
/// ('shorty', 'trilaminate', 'wing', ...), never display strings.
class GearBuoyancyTraits extends Equatable {
  final double? primaryThicknessMm;
  final List<double> panelThicknessesMm;
  final String? suitStyle;
  final String? shellMaterial;
  final String? bcdStyle;
  final double? liftCapacityKg;
  final String? gloveType;

  const GearBuoyancyTraits({
    this.primaryThicknessMm,
    this.panelThicknessesMm = const [],
    this.suitStyle,
    this.shellMaterial,
    this.bcdStyle,
    this.liftCapacityKg,
    this.gloveType,
  });

  static final RegExp _panelSeparators = RegExp(r'[/,\-]');
  static final RegExp _number = RegExp(r'(\d+(?:\.\d+)?)');

  /// Parses a thickness designation into its panel values, thickest-first by
  /// convention ("5/4/3" -> [5,4,3]). Tolerates `mm` suffixes, whitespace,
  /// and `,`/`-` separators; unparseable segments are skipped.
  static List<double> parsePanelsMm(String text) {
    final panels = <double>[];
    for (final segment in text.split(_panelSeparators)) {
      final match = _number.firstMatch(segment);
      if (match == null) continue;
      final value = double.tryParse(match.group(1)!);
      // Guard against overflow: a very long digit run parses to a non-finite
      // double, which would propagate NaN/Infinity into buoyancy predictions.
      if (value != null && value.isFinite) panels.add(value);
    }
    return panels;
  }

  @override
  List<Object?> get props => [
    primaryThicknessMm,
    panelThicknessesMm,
    suitStyle,
    shellMaterial,
    bcdStyle,
    liftCapacityKg,
    gloveType,
  ];
}
