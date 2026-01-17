import 'package:equatable/equatable.dart';

/// Represents a tidal harmonic constituent with amplitude and phase.
///
/// Tidal constituents are the building blocks of harmonic tide prediction.
/// Each constituent represents a specific astronomical forcing (lunar, solar,
/// or their combinations) that contributes to the overall tide.
///
/// Common constituents include:
/// - M2: Principal lunar semi-diurnal (largest contributor for most locations)
/// - S2: Principal solar semi-diurnal
/// - K1: Luni-solar diurnal
/// - O1: Principal lunar diurnal
class TideConstituent extends Equatable {
  /// Constituent name (e.g., 'M2', 'S2', 'K1')
  final String name;

  /// Amplitude in meters - the maximum contribution of this constituent
  final double amplitude;

  /// Phase (Greenwich phase lag) in degrees (0-360)
  ///
  /// Represents the time delay of the constituent's peak relative to
  /// the equilibrium tide at the Greenwich meridian.
  final double phase;

  const TideConstituent({
    required this.name,
    required this.amplitude,
    required this.phase,
  });

  /// Create from JSON map (e.g., from FES extraction data)
  factory TideConstituent.fromJson(String name, Map<String, dynamic> json) {
    return TideConstituent(
      name: name,
      amplitude: (json['amplitude'] as num).toDouble(),
      phase: (json['phase'] as num).toDouble(),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {'amplitude': amplitude, 'phase': phase};
  }

  TideConstituent copyWith({String? name, double? amplitude, double? phase}) {
    return TideConstituent(
      name: name ?? this.name,
      amplitude: amplitude ?? this.amplitude,
      phase: phase ?? this.phase,
    );
  }

  @override
  List<Object?> get props => [name, amplitude, phase];

  @override
  String toString() =>
      'TideConstituent($name: amp=${amplitude.toStringAsFixed(3)}m, phase=${phase.toStringAsFixed(1)}°)';
}
