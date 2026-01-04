import 'package:equatable/equatable.dart';

/// Represents a single tissue compartment in the Bühlmann decompression model.
///
/// The Bühlmann ZH-L16C model uses 16 tissue compartments with different
/// half-times for nitrogen and helium absorption/release.
class TissueCompartment extends Equatable {
  /// Compartment number (1-16)
  final int compartmentNumber;

  /// Nitrogen half-time in minutes
  final double halfTimeN2;

  /// Helium half-time in minutes
  final double halfTimeHe;

  /// Nitrogen M-value 'a' coefficient (bar)
  final double mValueAN2;

  /// Nitrogen M-value 'b' coefficient (dimensionless)
  final double mValueBN2;

  /// Helium M-value 'a' coefficient (bar)
  final double mValueAHe;

  /// Helium M-value 'b' coefficient (dimensionless)
  final double mValueBHe;

  /// Current nitrogen tissue tension (bar absolute)
  final double currentPN2;

  /// Current helium tissue tension (bar absolute)
  final double currentPHe;

  const TissueCompartment({
    required this.compartmentNumber,
    required this.halfTimeN2,
    required this.halfTimeHe,
    required this.mValueAN2,
    required this.mValueBN2,
    required this.mValueAHe,
    required this.mValueBHe,
    this.currentPN2 = 0.79, // Surface N2 tension at sea level
    this.currentPHe = 0.0,
  });

  /// Total inert gas tension (N2 + He) in bar
  double get totalInertGas => currentPN2 + currentPHe;

  /// Calculate blended 'a' coefficient based on gas fractions
  double get blendedA {
    final total = currentPN2 + currentPHe;
    if (total == 0) return mValueAN2;
    return (currentPN2 * mValueAN2 + currentPHe * mValueAHe) / total;
  }

  /// Calculate blended 'b' coefficient based on gas fractions
  double get blendedB {
    final total = currentPN2 + currentPHe;
    if (total == 0) return mValueBN2;
    return (currentPN2 * mValueBN2 + currentPHe * mValueBHe) / total;
  }

  /// M-value (maximum tolerated tissue tension) at surface
  double get surfaceMValue => blendedA + (1.0 / blendedB);

  /// Current tissue loading as percentage of surface M-value
  double get percentLoading => (totalInertGas / surfaceMValue) * 100;

  /// Calculate ceiling (minimum safe depth) in meters for this compartment
  /// Using gradient factor to add conservatism
  double ceiling({double gf = 1.0}) {
    // Ceiling in bar absolute = (P_tissue - a * gf) / (gf / b + 1 - gf)
    final a = blendedA;
    final b = blendedB;
    final pCeiling = (totalInertGas - a * gf) / (gf / b + 1 - gf);

    // Convert from bar absolute to meters (1 bar = 10m water)
    final ceilingMeters = (pCeiling - 1.0) * 10.0;

    // Ceiling cannot be negative (can't ascend above surface)
    return ceilingMeters < 0 ? 0 : ceilingMeters;
  }

  /// Create a copy with updated tissue tensions
  TissueCompartment copyWith({
    int? compartmentNumber,
    double? halfTimeN2,
    double? halfTimeHe,
    double? mValueAN2,
    double? mValueBN2,
    double? mValueAHe,
    double? mValueBHe,
    double? currentPN2,
    double? currentPHe,
  }) {
    return TissueCompartment(
      compartmentNumber: compartmentNumber ?? this.compartmentNumber,
      halfTimeN2: halfTimeN2 ?? this.halfTimeN2,
      halfTimeHe: halfTimeHe ?? this.halfTimeHe,
      mValueAN2: mValueAN2 ?? this.mValueAN2,
      mValueBN2: mValueBN2 ?? this.mValueBN2,
      mValueAHe: mValueAHe ?? this.mValueAHe,
      mValueBHe: mValueBHe ?? this.mValueBHe,
      currentPN2: currentPN2 ?? this.currentPN2,
      currentPHe: currentPHe ?? this.currentPHe,
    );
  }

  @override
  List<Object?> get props => [
    compartmentNumber,
    halfTimeN2,
    halfTimeHe,
    mValueAN2,
    mValueBN2,
    mValueAHe,
    mValueBHe,
    currentPN2,
    currentPHe,
  ];
}
