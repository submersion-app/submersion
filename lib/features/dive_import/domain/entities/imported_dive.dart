import 'package:equatable/equatable.dart';

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

/// A dive imported from an external source (wearable device, file, etc.)
class ImportedDive extends Equatable {
  final String sourceId;
  final String? sourceUuid;
  final ImportSource source;
  final DateTime startTime;
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
  final String? computerModel;
  final String? computerSerial;
  final String? computerFirmware;
  final List<ImportedTank> tanks;
  final List<ImportedProfileSample> profile;
  final String? sourceFileName;
  final String? sourceFileFormat;

  const ImportedDive({
    required this.sourceId,
    this.sourceUuid,
    required this.source,
    required this.startTime,
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
    this.computerModel,
    this.computerSerial,
    this.computerFirmware,
    this.tanks = const [],
    required this.profile,
    this.sourceFileName,
    this.sourceFileFormat,
  });

  Duration get duration => endTime.difference(startTime);
  int get durationSeconds => duration.inSeconds;

  @override
  List<Object?> get props => [
    sourceId,
    sourceUuid,
    source,
    startTime,
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
    computerModel,
    computerSerial,
    computerFirmware,
    tanks,
    profile,
    sourceFileName,
    sourceFileFormat,
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
  ];
}
