import 'package:equatable/equatable.dart';
import 'package:submersion/core/constants/enums.dart';

final RegExp _thicknessPattern = RegExp(r'(\d+(?:\.\d+)?)\s*mm');

/// Parses explicit suit thickness values in millimeters.
///
/// Accepts a single number with optional `mm` (`5`, `5mm`, `5.5 mm`) or
/// multi-panel suit formats where the first number is the primary thickness
/// (`8/7/6`, `8/7`, `4,3`, `6-3`, `6/5/4mm`).
final RegExp _explicitThicknessPattern = RegExp(
  r'^\s*(\d+(?:\.\d+)?)(?:\s*(?:mm|[/,\-]\s*\d+(?:\.\d+)?(?:\s*mm)?).*)?\s*$',
);

/// One equipment item as the prediction engine sees it: a feature with a
/// prior buoyancy term (lead-equivalent kg) and a prior strength (ridge
/// lambda, in virtual observations).
///
/// Priors come from user-entered metadata when present (strong), otherwise
/// from type defaults (weak). The engine's learned coefficient converges
/// away from the prior as real dives accumulate.
class GearFeature extends Equatable {
  final String id;
  final String label;
  final double priorKg;
  final double priorStrength;
  final double dryMassKg;
  final bool hasUserSpec;

  const GearFeature({
    required this.id,
    required this.label,
    required this.priorKg,
    required this.priorStrength,
    required this.dryMassKg,
    this.hasUserSpec = false,
  });

  static const double _metadataStrength = 8.0;
  static const double _typeDefaultStrength = 2.0;

  /// Builds a feature from equipment fields. Throws [ArgumentError] for
  /// [EquipmentType.weights] (lead is the predicted quantity) and
  /// [EquipmentType.tank] (tanks are modeled from the tank list).
  factory GearFeature.fromEquipment({
    required String id,
    required EquipmentType type,
    required String name,
    String? size,
    String? thickness,
    double? buoyancyKg,
    double? weightKg,
  }) {
    if (type == EquipmentType.weights || type == EquipmentType.tank) {
      throw ArgumentError('EquipmentType.${type.name} is not a gear feature');
    }

    final double prior;
    final double strength;
    final bool hasUserSpec;
    if (buoyancyKg != null) {
      prior = buoyancyKg;
      strength = _metadataStrength;
      hasUserSpec = true;
    } else {
      prior = _typePrior(type, name, size, thickness);
      strength = _typeDefaultStrength;
      hasUserSpec = false;
    }

    return GearFeature(
      id: id,
      label: name,
      priorKg: prior,
      priorStrength: strength,
      dryMassKg: weightKg ?? _typeDryMass(type),
      hasUserSpec: hasUserSpec,
    );
  }

  static double _typePrior(
    EquipmentType type,
    String name,
    String? size,
    String? thickness,
  ) {
    switch (type) {
      case EquipmentType.wetsuit:
        final thicknessNum =
            _parseThicknessMm(thickness ?? '', _explicitThicknessPattern) ??
            _parseThicknessMm(size ?? '', _thicknessPattern) ??
            _parseThicknessMm(name, _thicknessPattern);
        if (thicknessNum != null) return thicknessNum.clamp(0.0, 8.0);
        return 4.0;
      case EquipmentType.drysuit:
        return 10.0;
      case EquipmentType.bcd:
        return -0.5;
      case EquipmentType.hood:
        return 0.3;
      case EquipmentType.gloves:
        return 0.2;
      case EquipmentType.boots:
        return 0.4;
      default:
        return 0.0;
    }
  }

  static double _typeDryMass(EquipmentType type) => switch (type) {
    EquipmentType.wetsuit => 2.0,
    EquipmentType.drysuit => 3.0,
    EquipmentType.bcd => 3.5,
    _ => 0.5,
  };

  static double? _parseThicknessMm(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  @override
  List<Object?> get props => [
    id,
    label,
    priorKg,
    priorStrength,
    dryMassKg,
    hasUserSpec,
  ];
}
