import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

/// Source of imported dive data
enum ImportSource { appleWatch, garmin, suunto, uddf }

/// Extension for display names
extension ImportSourceExtension on ImportSource {
  String get displayName {
    switch (this) {
      case ImportSource.appleWatch:
        return 'Apple Watch';
      case ImportSource.garmin:
        return 'Garmin';
      case ImportSource.suunto:
        return 'Suunto';
      case ImportSource.uddf:
        return 'UDDF';
    }
  }
}

/// A tank parsed from an imported dive (air-integration).
class ImportedTank extends Equatable {
  const ImportedTank({
    required this.order,
    this.startPressureBar,
    this.endPressureBar,
    this.volumeUsedLiters,
    this.volumeLiters,
    this.o2Percent,
    this.hePercent,
  });

  final int order;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? volumeUsedLiters;

  /// Configured cylinder volume in liters (water volume). Derived for Garmin
  /// air-integration tanks; null when unknown.
  final double? volumeLiters;
  final double? o2Percent;
  final double? hePercent;

  @override
  List<Object?> get props => [
    order,
    startPressureBar,
    endPressureBar,
    volumeUsedLiters,
    volumeLiters,
    o2Percent,
    hePercent,
  ];
}

/// A single tank-pressure reading attached to a profile sample.
class ImportedTankPressureSample extends Equatable {
  const ImportedTankPressureSample({
    required this.tankIndex,
    required this.pressureBar,
  });

  final int tankIndex;
  final double pressureBar;

  @override
  List<Object?> get props => [tankIndex, pressureBar];
}

/// A gas switch during an imported dive, addressing the tank positionally
/// (by [ImportedTank.order] / list index).
class ImportedGasSwitch extends Equatable {
  const ImportedGasSwitch({
    required this.timeSeconds,
    required this.tankIndex,
    this.depth,
  });

  /// Seconds since dive start.
  final int timeSeconds;

  /// Index into [ImportedDive.tanks] of the tank switched to.
  final int tankIndex;

  /// Depth in meters at the switch, when derivable.
  final double? depth;

  @override
  List<Object?> get props => [timeSeconds, tankIndex, depth];
}

/// A dive imported from an external source (wearable device, file, etc.)
class ImportedDive extends Equatable {
  final String sourceId;
  final String? sourceUuid;
  final ImportSource source;
  final DateTime startTime;

  /// The real instant the source recorded the start at, flagged UTC, when it
  /// reports one; [startTime] is the wall clock the diver saw. Only HealthKit
  /// sets it: a re-import compares it with a saved dive's start to recognize
  /// a dive the import saved as the instant before #2811 (issue #2812).
  final DateTime? startInstant;
  final DateTime endTime;
  final double maxDepth;
  final double? avgDepth;
  final double? minTemperature;
  final double? maxTemperature;
  final double? avgHeartRate;
  final double? latitude;
  final double? longitude;
  final double? exitLatitude;
  final double? exitLongitude;
  final int? diveNumber;
  final int? bottomTimeSeconds;
  final int? surfaceIntervalSeconds;
  final double? cnsStart;
  final double? cnsEnd;
  final double? otu;
  final String? waterType;
  final String? decoModel;
  final int? gfLow;
  final int? gfHigh;

  /// The computer's manufacturer when the file names it (FIT `file_id`,
  /// issue #3106); null when it does not.
  final String? computerManufacturer;
  final String? computerModel;
  final String? computerSerial;
  final String? computerFirmware;
  final List<ImportedTank> tanks;
  final List<ImportedGasSwitch> gasSwitches;
  final List<ImportedProfileSample> profile;
  final String? sourceFileName;
  final String? sourceFileFormat;

  /// Tissue state the dive computer itself reported, when the source
  /// carried one. Never computed here.
  final ComputerTissueSnapshot? computerTissue;

  const ImportedDive({
    required this.sourceId,
    this.sourceUuid,
    required this.source,
    required this.startTime,
    this.startInstant,
    required this.endTime,
    required this.maxDepth,
    this.avgDepth,
    this.minTemperature,
    this.maxTemperature,
    this.avgHeartRate,
    this.latitude,
    this.longitude,
    this.exitLatitude,
    this.exitLongitude,
    this.diveNumber,
    this.bottomTimeSeconds,
    this.surfaceIntervalSeconds,
    this.cnsStart,
    this.cnsEnd,
    this.otu,
    this.waterType,
    this.decoModel,
    this.gfLow,
    this.gfHigh,
    this.computerManufacturer,
    this.computerModel,
    this.computerSerial,
    this.computerFirmware,
    this.tanks = const [],
    this.gasSwitches = const [],
    required this.profile,
    this.sourceFileName,
    this.sourceFileFormat,
    this.computerTissue,
  });

  Duration get duration => endTime.difference(startTime);
  int get durationSeconds => duration.inSeconds;

  @override
  List<Object?> get props => [
    sourceId,
    sourceUuid,
    source,
    startTime,
    startInstant,
    endTime,
    maxDepth,
    avgDepth,
    minTemperature,
    maxTemperature,
    avgHeartRate,
    latitude,
    longitude,
    exitLatitude,
    exitLongitude,
    diveNumber,
    bottomTimeSeconds,
    surfaceIntervalSeconds,
    cnsStart,
    cnsEnd,
    otu,
    waterType,
    decoModel,
    gfLow,
    gfHigh,
    computerManufacturer,
    computerModel,
    computerSerial,
    computerFirmware,
    tanks,
    gasSwitches,
    profile,
    sourceFileName,
    sourceFileFormat,
    computerTissue,
  ];
}

/// A single sample point in an imported dive profile
class ImportedProfileSample extends Equatable {
  final int timeSeconds;
  final double depth;
  final double? temperature;
  final int? heartRate;
  final double? cns;
  final int? ndlSeconds;
  final int? ttsSeconds;
  final double? ceiling;
  final List<ImportedTankPressureSample>? tankPressures;

  /// Computer-reported GF99 at this sample, whole percent.
  final int? gf99;

  /// Computer-reported aggregate N2 tissue loading, whole percent.
  final int? n2Load;

  const ImportedProfileSample({
    required this.timeSeconds,
    required this.depth,
    this.temperature,
    this.heartRate,
    this.cns,
    this.ndlSeconds,
    this.ttsSeconds,
    this.ceiling,
    this.tankPressures,
    this.gf99,
    this.n2Load,
  });

  ImportedProfileSample copyWith({
    int? timeSeconds,
    double? depth,
    double? temperature,
    int? heartRate,
    double? cns,
    int? ndlSeconds,
    int? ttsSeconds,
    double? ceiling,
    List<ImportedTankPressureSample>? tankPressures,
    int? gf99,
    int? n2Load,
  }) {
    return ImportedProfileSample(
      timeSeconds: timeSeconds ?? this.timeSeconds,
      depth: depth ?? this.depth,
      temperature: temperature ?? this.temperature,
      heartRate: heartRate ?? this.heartRate,
      cns: cns ?? this.cns,
      ndlSeconds: ndlSeconds ?? this.ndlSeconds,
      ttsSeconds: ttsSeconds ?? this.ttsSeconds,
      ceiling: ceiling ?? this.ceiling,
      tankPressures: tankPressures ?? this.tankPressures,
      gf99: gf99 ?? this.gf99,
      n2Load: n2Load ?? this.n2Load,
    );
  }

  @override
  List<Object?> get props => [
    timeSeconds,
    depth,
    temperature,
    heartRate,
    cns,
    ndlSeconds,
    ttsSeconds,
    ceiling,
    tankPressures,
    gf99,
    n2Load,
  ];
}
