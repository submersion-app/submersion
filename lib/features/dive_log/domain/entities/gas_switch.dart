import 'package:equatable/equatable.dart';

/// Represents a gas switch event during a dive.
///
/// Tracks when the diver switched to a different tank/gas mix.
class GasSwitch extends Equatable {
  /// Unique identifier
  final String id;

  /// Dive this switch occurred on
  final String diveId;

  /// Timestamp in seconds from dive start
  final int timestamp;

  /// Tank switched to
  final String tankId;

  /// Depth at which switch occurred (meters)
  final double? depth;

  /// When this record was created
  final DateTime createdAt;

  const GasSwitch({
    required this.id,
    required this.diveId,
    required this.timestamp,
    required this.tankId,
    this.depth,
    required this.createdAt,
  });

  /// Timestamp formatted as MM:SS
  String get timestampFormatted {
    final minutes = timestamp ~/ 60;
    final seconds = timestamp % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Depth formatted with unit
  String depthFormatted({bool metric = true}) {
    if (depth == null) return '-';
    if (metric) {
      return '${depth!.toStringAsFixed(1)}m';
    } else {
      final feet = (depth! * 3.28084).round();
      return '${feet}ft';
    }
  }

  GasSwitch copyWith({
    String? id,
    String? diveId,
    int? timestamp,
    String? tankId,
    double? depth,
    DateTime? createdAt,
  }) {
    return GasSwitch(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      timestamp: timestamp ?? this.timestamp,
      tankId: tankId ?? this.tankId,
      depth: depth ?? this.depth,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        diveId,
        timestamp,
        tankId,
        depth,
        createdAt,
      ];
}

/// Extended gas switch info including tank details (for display purposes).
class GasSwitchWithTank extends Equatable {
  /// The gas switch event
  final GasSwitch gasSwitch;

  /// Tank name/label
  final String tankName;

  /// Gas mix description (e.g., "EAN32", "21/35")
  final String gasMix;

  /// O2 fraction (0.0-1.0)
  final double o2Fraction;

  /// He fraction (0.0-1.0)
  final double heFraction;

  const GasSwitchWithTank({
    required this.gasSwitch,
    required this.tankName,
    required this.gasMix,
    required this.o2Fraction,
    this.heFraction = 0.0,
  });

  /// N2 fraction
  double get n2Fraction => 1.0 - o2Fraction - heFraction;

  /// Whether this is a nitrox mix (elevated O2, no He)
  bool get isNitrox => o2Fraction > 0.21 && heFraction == 0;

  /// Whether this is a trimix (contains He)
  bool get isTrimix => heFraction > 0;

  /// Whether this is air
  bool get isAir => o2Fraction >= 0.20 && o2Fraction <= 0.22 && heFraction == 0;

  /// ppO2 at switch depth
  double get ppO2AtDepth {
    if (gasSwitch.depth == null) return o2Fraction;
    final ambientPressure = 1.0 + (gasSwitch.depth! / 10.0);
    return ambientPressure * o2Fraction;
  }

  /// MOD (Maximum Operating Depth) for this gas at 1.4 bar ppO2
  double get modWorking {
    if (o2Fraction <= 0) return 0;
    return ((1.4 / o2Fraction) - 1.0) * 10.0;
  }

  /// MOD for this gas at 1.6 bar ppO2 (deco limit)
  double get modDeco {
    if (o2Fraction <= 0) return 0;
    return ((1.6 / o2Fraction) - 1.0) * 10.0;
  }

  /// Delegate to gasSwitch properties
  String get id => gasSwitch.id;
  String get diveId => gasSwitch.diveId;
  int get timestamp => gasSwitch.timestamp;
  String get tankId => gasSwitch.tankId;
  double? get depth => gasSwitch.depth;
  DateTime get createdAt => gasSwitch.createdAt;

  String get timestampFormatted => gasSwitch.timestampFormatted;
  String depthFormatted({bool metric = true}) =>
      gasSwitch.depthFormatted(metric: metric);

  @override
  List<Object?> get props => [
        gasSwitch,
        tankName,
        gasMix,
        o2Fraction,
        heFraction,
      ];
}
