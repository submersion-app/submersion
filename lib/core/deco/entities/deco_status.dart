import 'package:equatable/equatable.dart';

import 'package:submersion/core/deco/entities/tissue_compartment.dart';

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

  /// Whether the diver is currently in decompression obligation.
  ///
  /// This is based on NDL being negative (can't ascend directly to surface).
  /// Note: `ceilingMeters` may show small positive values with conservative
  /// GF settings even on recreational dives - this is for ascent planning
  /// display, not for determining deco obligation.
  bool get inDeco => ndlSeconds < 0;

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

  /// GF99: The maximum gradient factor across all compartments at current
  /// ambient pressure, expressed as a percentage (0-100+).
  ///
  /// This is the standard "GF99" metric used in dive computers. It shows
  /// how close the most-loaded compartment is to its M-value at the
  /// current depth. Values > 100 mean the M-value is being exceeded.
  double get gf99 {
    if (compartments.isEmpty) return 0.0;
    double maxGf = double.negativeInfinity;
    for (final comp in compartments) {
      final gf = comp.gradientFactor(ambientPressureBar);
      if (gf > maxGf) maxGf = gf;
    }
    // Clamp at 0: negative GF means undersaturation (ongassing),
    // which is not meaningful to display.
    return (maxGf * 100.0).clamp(0.0, double.infinity);
  }

  /// SurfGF: The maximum surface gradient factor across all compartments,
  /// expressed as a percentage (0-100+).
  ///
  /// Shows what GF would be if the diver ascended directly to the surface
  /// right now. Values > 100 indicate the diver cannot safely ascend
  /// directly to the surface (decompression obligation).
  double get surfGf {
    if (compartments.isEmpty) return 0.0;
    double maxGf = double.negativeInfinity;
    for (final comp in compartments) {
      final gf = comp.surfaceGradientFactor;
      if (gf > maxGf) maxGf = gf;
    }
    // Clamp at 0: negative SurfGF means all tissues are below surface
    // equilibrium, which is not meaningful to display.
    return (maxGf * 100.0).clamp(0.0, double.infinity);
  }

  /// The compartment number that is leading by GF99 (at current depth).
  ///
  /// This may differ from [leadingCompartmentNumber] which uses surface
  /// M-value-based percent loading.
  int get gf99LeadingCompartmentNumber {
    if (compartments.isEmpty) return 0;
    int leadingIdx = 0;
    double maxGf = double.negativeInfinity;
    for (int i = 0; i < compartments.length; i++) {
      final gf = compartments[i].gradientFactor(ambientPressureBar);
      if (gf > maxGf) {
        maxGf = gf;
        leadingIdx = i;
      }
    }
    return compartments[leadingIdx].compartmentNumber;
  }

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
  List<Object?> get props => [
    depthMeters,
    durationSeconds,
    gasName,
    isDeepStop,
  ];
}
