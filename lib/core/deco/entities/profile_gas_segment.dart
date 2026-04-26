import 'package:equatable/equatable.dart';

/// Describes the active breathing gas for a range of profile timestamps.
class ProfileGasSegment extends Equatable {
  /// Timestamp in seconds from dive start when this gas becomes active.
  final int startTimestamp;

  /// Nitrogen fraction (0.0-1.0).
  final double fN2;

  /// Helium fraction (0.0-1.0).
  final double fHe;

  const ProfileGasSegment({
    required this.startTimestamp,
    required this.fN2,
    this.fHe = 0.0,
  });

  @override
  List<Object?> get props => [startTimestamp, fN2, fHe];
}
