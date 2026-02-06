import 'package:equatable/equatable.dart';

/// Source of wearable dive data
enum WearableSource { appleWatch, garmin, suunto }

/// Extension for display names
extension WearableSourceExtension on WearableSource {
  String get displayName {
    switch (this) {
      case WearableSource.appleWatch:
        return 'Apple Watch';
      case WearableSource.garmin:
        return 'Garmin';
      case WearableSource.suunto:
        return 'Suunto';
    }
  }
}

/// A dive imported from a wearable device
class WearableDive extends Equatable {
  final String sourceId;
  final WearableSource source;
  final DateTime startTime;
  final DateTime endTime;
  final double maxDepth;
  final double? avgDepth;
  final double? minTemperature;
  final double? maxTemperature;
  final double? avgHeartRate;
  final double? latitude;
  final double? longitude;
  final List<WearableProfileSample> profile;

  const WearableDive({
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

/// A single sample point in a wearable dive profile
class WearableProfileSample extends Equatable {
  final int timeSeconds;
  final double depth;
  final double? temperature;
  final int? heartRate;

  const WearableProfileSample({
    required this.timeSeconds,
    required this.depth,
    this.temperature,
    this.heartRate,
  });

  @override
  List<Object?> get props => [timeSeconds, depth, temperature, heartRate];
}
