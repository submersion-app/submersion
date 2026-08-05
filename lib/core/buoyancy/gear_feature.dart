import 'package:equatable/equatable.dart';
import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';
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
  static const double _attributeStrength = 4.0;
  static const double _typeDefaultStrength = 2.0;

  /// Builds a feature from equipment fields. Throws [ArgumentError] for
  /// [EquipmentType.weights] (lead is the predicted quantity) and
  /// [EquipmentType.tank] (tanks are modeled from the tank list).
  ///
  /// The prior is resolved through a strict ladder:
  /// 1. Explicit [buoyancyKg] -> strength 8.0 (user told us the answer).
  /// 2. Attribute-derived physics prior from [traits] -> strength 4.0.
  /// 3. Legacy thickness parsed from [thickness]/[size]/[name] strings
  ///    (wetsuits only) -> strength 4.0 (parsed text carries real info).
  /// 4. Flat type default -> strength 2.0.
  factory GearFeature.fromEquipment({
    required String id,
    required EquipmentType type,
    required String name,
    String? size,
    String? thickness,
    double? buoyancyKg,
    double? weightKg,
    GearBuoyancyTraits? traits,
  }) {
    if (type == EquipmentType.weights || type == EquipmentType.tank) {
      throw ArgumentError('EquipmentType.${type.name} is not a gear feature');
    }

    final double prior;
    final double strength;
    final bool hasUserSpec;
    // Numeric equipment attributes are parsed with double.tryParse, which has
    // no finiteness guard, so a value like 1e309 arrives here as Infinity.
    // Non-finite user numbers are treated as absent, never as a spec.
    final userBuoyancy = _finiteOrNull(buoyancyKg);
    if (userBuoyancy != null) {
      prior = userBuoyancy;
      strength = _metadataStrength;
      hasUserSpec = true;
    } else {
      hasUserSpec = false;
      final attributed = _attributePrior(type, traits);
      if (attributed != null) {
        prior = attributed;
        strength = _attributeStrength;
      } else {
        final legacyMm = type == EquipmentType.wetsuit
            ? _legacyWetsuitThicknessMm(name, size, thickness)
            : null;
        if (legacyMm != null) {
          // A thickness parsed from free text carries real information, so
          // it gets the same intermediate trust as attribute-derived priors.
          prior = legacyMm.clamp(0.0, 10.0);
          strength = _attributeStrength;
        } else {
          prior = _typeDefault(type);
          strength = _typeDefaultStrength;
        }
      }
    }

    return GearFeature(
      id: id,
      label: name,
      priorKg: prior,
      priorStrength: strength,
      dryMassKg: _finiteOrNull(weightKg) ?? _typeDryMass(type),
      hasUserSpec: hasUserSpec,
    );
  }

  /// Physics-informed prior from equipment attributes, or null when the
  /// item's attributes say nothing useful for its type. Factor values are
  /// normative from the design spec; unknown choice keys (future catalog
  /// additions) fall through to the absent branch and never throw.
  static double? _attributePrior(EquipmentType type, GearBuoyancyTraits? t) {
    if (t == null) return null;
    final mm = _effectiveThicknessMm(t);
    switch (type) {
      case EquipmentType.wetsuit:
        if (mm == null) return null;
        return (mm * _suitStyleFactor(t.suitStyle)).clamp(0.0, 10.0);
      case EquipmentType.drysuit:
        return switch (t.shellMaterial) {
          'neoprene' => 13.0,
          'crushed_neoprene' => 11.0,
          'trilaminate' => 9.0,
          'vulcanized_rubber' => 9.0,
          _ => null,
        };
      case EquipmentType.hood:
        if (mm == null) return null;
        return (0.10 * mm).clamp(0.0, 2.0);
      case EquipmentType.gloves:
        if (mm == null) return null;
        return (0.06 * mm * _gloveTypeFactor(t.gloveType)).clamp(0.0, 2.0);
      case EquipmentType.boots:
        if (mm == null) return null;
        return (0.12 * mm).clamp(0.0, 2.0);
      case EquipmentType.bcd:
        // Unknown/future style keys map to null (no signal) so they fall
        // through to the type default rather than claiming attribute-level
        // strength off the switch's fallback.
        final styleOffset = switch (t.bcdStyle) {
          'jacket' => 0.5,
          'back_inflate' => 0.0,
          'wing' => -0.5,
          'sidemount' => -0.3,
          _ => null,
        };
        // Lift capacity is physically non-negative; a signed or non-finite
        // value from the free numeric field is not a usable signal.
        final rawLift = t.liftCapacityKg;
        final lift = (rawLift != null && rawLift.isFinite && rawLift > 0)
            ? rawLift
            : 0.0;
        if (styleOffset == null && lift == 0.0) return null;
        // An absent or unknown style contributes the absent-style base.
        final base = styleOffset ?? -0.5;
        final bladder = 0.01 * lift;
        return (base + bladder).clamp(-2.0, 2.0);
      default:
        return null;
    }
  }

  /// Area-weighted panel blend: torso (thickest, written first) 0.5 + mean
  /// of the remaining panels 0.5. Single panel is itself. Clamped [0,15] mm.
  static double? _effectiveThicknessMm(GearBuoyancyTraits t) {
    final panels = t.panelThicknessesMm;
    double? mm;
    if (panels.length > 1) {
      final rest = panels.sublist(1);
      final restMean = rest.reduce((a, b) => a + b) / rest.length;
      mm = panels.first * 0.5 + restMean * 0.5;
    } else if (panels.length == 1) {
      mm = panels.first;
    } else {
      mm = t.primaryThicknessMm;
    }
    // A non-finite mm (NaN survives clamp, and either poisons predictions)
    // means no usable thickness signal.
    if (mm == null || !mm.isFinite) return null;
    return mm.clamp(0.0, 15.0);
  }

  /// The value when it is a finite number, else null. Numeric equipment
  /// attributes are user-entered via double.tryParse (no finiteness guard),
  /// so NaN/Infinity must be filtered before reaching the prediction math.
  static double? _finiteOrNull(double? v) =>
      (v != null && v.isFinite) ? v : null;

  static double _suitStyleFactor(String? style) => switch (style) {
    'semi_dry' => 1.1,
    'two_piece' => 1.35,
    'shorty' => 0.55,
    _ => 1.0,
  };

  static double _gloveTypeFactor(String? gloveType) => switch (gloveType) {
    'mitt' => 1.15,
    'dry' => 0.5,
    _ => 1.0,
  };

  static double? _legacyWetsuitThicknessMm(
    String name,
    String? size,
    String? thickness,
  ) =>
      _parseThicknessMm(thickness ?? '', _explicitThicknessPattern) ??
      _parseThicknessMm(size ?? '', _thicknessPattern) ??
      _parseThicknessMm(name, _thicknessPattern);

  static double _typeDefault(EquipmentType type) => switch (type) {
    EquipmentType.wetsuit => 4.0,
    EquipmentType.drysuit => 10.0,
    EquipmentType.bcd => -0.5,
    EquipmentType.hood => 0.3,
    EquipmentType.gloves => 0.2,
    EquipmentType.boots => 0.4,
    _ => 0.0,
  };

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
