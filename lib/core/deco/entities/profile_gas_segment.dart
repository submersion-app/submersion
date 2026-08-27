import 'package:equatable/equatable.dart';

/// Describes the active breathing gas for a range of profile timestamps.
class ProfileGasSegment extends Equatable {
  /// Timestamp in seconds from dive start when this gas becomes active.
  final int startTimestamp;

  /// Nitrogen fraction (0.0-1.0).
  final double fN2;

  /// Helium fraction (0.0-1.0).
  final double fHe;

  /// CCR setpoint in bar for this segment; null means open circuit.
  /// When set, [fN2]/[fHe] describe the DILUENT and inert-gas loading uses
  /// constant-ppO2 partitioning instead of open-circuit fractions.
  final double? setpoint;

  const ProfileGasSegment({
    required this.startTimestamp,
    required this.fN2,
    this.fHe = 0.0,
    this.setpoint,
  });

  @override
  List<Object?> get props => [startTimestamp, fN2, fHe, setpoint];
}
