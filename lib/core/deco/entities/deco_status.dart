import 'package:equatable/equatable.dart';

import 'tissue_compartment.dart';

/// Represents the current decompression status at a point in time.
class DecoStatus extends Equatable {
  /// All 16 tissue compartments with current loading
  final List<TissueCompartment> compartments;

  /// No-Decompression Limit in seconds at current depth
  /// -1 if currently in decompression obligation
  final int ndlSeconds;

  /// Decompression ceiling in meters (0 if no deco obligation)
  final double ceilingMeters;

  /// Time To Surface in seconds (including deco stops)
  final int ttsSeconds;

  /// Gradient Factor Low (0.0 - 1.0)
  final double gfLow;

  /// Gradient Factor High (0.0 - 1.0)
  final double gfHigh;

  /// Required decompression stops (empty if no deco)
  final List<DecoStop> decoStops;

  /// Current depth in meters
  final double currentDepthMeters;

  /// Current ambient pressure in bar absolute
  final double ambientPressureBar;

  const DecoStatus({
    required this.compartments,
    required this.ndlSeconds,
    required this.ceilingMeters,
    required this.ttsSeconds,
    required this.gfLow,
    required this.gfHigh,
    required this.decoStops,
    required this.currentDepthMeters,
    required this.ambientPressureBar,
  });

  /// Whether the diver is currently in decompression obligation
  bool get inDeco => ceilingMeters > 0 || decoStops.isNotEmpty;

  /// Get the leading (most saturated) compartment
  TissueCompartment get leadingCompartment {
    return compartments.reduce(
      (a, b) => a.percentLoading > b.percentLoading ? a : b,
    );
  }

  /// Leading compartment loading percentage
  double get leadingCompartmentLoading => leadingCompartment.percentLoading;

  /// Leading compartment number (1-16)
  int get leadingCompartmentNumber => leadingCompartment.compartmentNumber;

  /// NDL formatted as minutes:seconds string
  String get ndlFormatted {
    if (ndlSeconds < 0) return 'DECO';
    final minutes = ndlSeconds ~/ 60;
    final seconds = ndlSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// TTS formatted as minutes string
  String get ttsFormatted {
    final minutes = (ttsSeconds / 60).ceil();
    return '${minutes}min';
  }

  /// Total decompression time in seconds
  int get totalDecoTime =>
      decoStops.fold(0, (sum, stop) => sum + stop.durationSeconds);

  /// Get ceiling for first required stop (usually 3m increments)
  double get firstStopDepth {
    if (decoStops.isEmpty) return 0;
    return decoStops.first.depthMeters;
  }

  /// Create initial surface-saturated status
  factory DecoStatus.surfaceSaturated({
    required List<TissueCompartment> compartments,
    double gfLow = 0.3,
    double gfHigh = 0.7,
  }) {
    return DecoStatus(
      compartments: compartments,
      ndlSeconds: 999 * 60, // Effectively unlimited at surface
      ceilingMeters: 0,
      ttsSeconds: 0,
      gfLow: gfLow,
      gfHigh: gfHigh,
      decoStops: const [],
      currentDepthMeters: 0,
      ambientPressureBar: 1.0,
    );
  }

  DecoStatus copyWith({
    List<TissueCompartment>? compartments,
    int? ndlSeconds,
    double? ceilingMeters,
    int? ttsSeconds,
    double? gfLow,
    double? gfHigh,
    List<DecoStop>? decoStops,
    double? currentDepthMeters,
    double? ambientPressureBar,
  }) {
    return DecoStatus(
      compartments: compartments ?? this.compartments,
      ndlSeconds: ndlSeconds ?? this.ndlSeconds,
      ceilingMeters: ceilingMeters ?? this.ceilingMeters,
      ttsSeconds: ttsSeconds ?? this.ttsSeconds,
      gfLow: gfLow ?? this.gfLow,
      gfHigh: gfHigh ?? this.gfHigh,
      decoStops: decoStops ?? this.decoStops,
      currentDepthMeters: currentDepthMeters ?? this.currentDepthMeters,
      ambientPressureBar: ambientPressureBar ?? this.ambientPressureBar,
    );
  }

  @override
  List<Object?> get props => [
        compartments,
        ndlSeconds,
        ceilingMeters,
        ttsSeconds,
        gfLow,
        gfHigh,
        decoStops,
        currentDepthMeters,
        ambientPressureBar,
      ];
}

/// Represents a single decompression stop.
class DecoStop extends Equatable {
  /// Stop depth in meters
  final double depthMeters;

  /// Stop duration in seconds
  final int durationSeconds;

  /// Gas to use at this stop (null = current gas)
  final String? gasName;

  /// Whether this is a deep stop (below 9m)
  final bool isDeepStop;

  const DecoStop({
    required this.depthMeters,
    required this.durationSeconds,
    this.gasName,
    this.isDeepStop = false,
  });

  /// Duration formatted as minutes
  String get durationFormatted {
    final minutes = (durationSeconds / 60).ceil();
    return '${minutes}min';
  }

  /// Depth formatted with unit
  String depthFormatted({bool metric = true}) {
    if (metric) {
      return '${depthMeters.toInt()}m';
    } else {
      final feet = (depthMeters * 3.28084).round();
      return '${feet}ft';
    }
  }

  @override
  List<Object?> get props =>
      [depthMeters, durationSeconds, gasName, isDeepStop];
}
