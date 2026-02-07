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

/// A dive imported from an external source (wearable device, file, etc.)
class ImportedDive extends Equatable {
  final String sourceId;
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
  final List<ImportedProfileSample> profile;

  const ImportedDive({
    required this.sourceId,
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
    required this.profile,
  });

  Duration get duration => endTime.difference(startTime);
  int get durationSeconds => duration.inSeconds;

  @override
  List<Object?> get props => [
    sourceId,
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
    profile,
  ];
}

/// A single sample point in an imported dive profile
class ImportedProfileSample extends Equatable {
  final int timeSeconds;
  final double depth;
  final double? temperature;
  final int? heartRate;

  const ImportedProfileSample({
    required this.timeSeconds,
    required this.depth,
    this.temperature,
    this.heartRate,
  });

  @override
  List<Object?> get props => [timeSeconds, depth, temperature, heartRate];
}
