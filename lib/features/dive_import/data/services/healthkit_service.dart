import 'dart:io';

import 'package:health/health.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';

/// HealthKit implementation of HealthImportService for Apple platforms.
///
/// Fetches underwater diving workouts and associated data (depth, temperature,
/// heart rate, GPS) from Apple HealthKit. Only available on iOS and macOS.
class HealthKitService implements HealthImportService {
  HealthKitService({Health? health}) : _health = health ?? Health();

  final Health _health;

  /// HealthKit data types we need to read for dive imports.
  static const List<HealthDataType> _readTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
  ];

  @override
  ImportSource get source => ImportSource.appleWatch;

  @override
  Future<bool> isAvailable() async {
    // HealthKit is only available on iOS and macOS
    if (!Platform.isIOS && !Platform.isMacOS) {
      return false;
    }

    try {
      return await _health.hasPermissions(_readTypes) ?? false;
    } catch (e) {
      // HealthKit not available on this device
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return false;
    }

    try {
      final hasPerms = await _health.hasPermissions(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      return hasPerms ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return false;
    }

    try {
      // Configure the health plugin
      await _health.configure();

      // Request authorization for read types
      final authorized = await _health.requestAuthorization(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );

      return authorized;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<ImportedDive>> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!await hasPermissions()) {
      return [];
    }

    try {
      // Fetch workouts in the date range
      final workouts = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: startDate,
        endTime: endDate,
      );

      // Filter for underwater diving workouts only
      final diveWorkouts = workouts.where((data) {
        if (data.value is! WorkoutHealthValue) return false;
        final workout = data.value as WorkoutHealthValue;
        return workout.workoutActivityType ==
            HealthWorkoutActivityType.UNDERWATER_DIVING;
      }).toList();

      // Convert each workout to an ImportedDive
      final dives = <ImportedDive>[];
      for (final workout in diveWorkouts) {
        final dive = await _workoutToDive(workout);
        if (dive != null) {
          dives.add(dive);
        }
      }

      // Sort by start time descending (newest first)
      dives.sort((a, b) => b.startTime.compareTo(a.startTime));

      return dives;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<ImportedProfileSample>> fetchDiveProfile(String sourceId) async {
    // Profile data is already fetched as part of the dive
    // This method exists for lazy loading if needed in the future
    return [];
  }

  /// Convert a HealthKit workout to an ImportedDive entity.
  Future<ImportedDive?> _workoutToDive(HealthDataPoint workoutPoint) async {
    if (workoutPoint.value is! WorkoutHealthValue) return null;

    final workout = workoutPoint.value as WorkoutHealthValue;
    final startTime = workoutPoint.dateFrom;
    final endTime = workoutPoint.dateTo;

    // Fetch associated samples for this workout time range
    final samples = await _fetchWorkoutSamples(startTime, endTime);

    // Calculate summary statistics
    final maxDepth = _calculateMaxDepth(samples);
    final avgDepth = _calculateAvgDepth(samples);
    final tempRange = _calculateTemperatureRange(samples);
    final avgHeartRate = _calculateAvgHeartRate(samples);

    // Extract GPS coordinates if available
    final gps = _extractGpsCoordinates(workout);

    return ImportedDive(
      sourceId: workoutPoint.uuid,
      source: ImportSource.appleWatch,
      startTime: startTime,
      endTime: endTime,
      maxDepth: maxDepth,
      avgDepth: avgDepth > 0 ? avgDepth : null,
      minTemperature: tempRange.min,
      maxTemperature: tempRange.max,
      avgHeartRate: avgHeartRate,
      latitude: gps?.latitude,
      longitude: gps?.longitude,
      profile: samples,
    );
  }

  /// Fetch depth, temperature, and heart rate samples for a workout.
  Future<List<ImportedProfileSample>> _fetchWorkoutSamples(
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      // Fetch heart rate samples (depth and temperature may not be available
      // in the standard health package - depends on device capabilities)
      final heartRateData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: endTime,
      );

      // Build profile samples from heart rate data
      // Note: Actual depth/temperature would come from workout samples
      // which require native platform code beyond the health package
      final samples = <ImportedProfileSample>[];

      for (final dataPoint in heartRateData) {
        if (dataPoint.value is! NumericHealthValue) continue;

        final hrValue = dataPoint.value as NumericHealthValue;
        final timeSeconds = dataPoint.dateFrom.difference(startTime).inSeconds;

        samples.add(
          ImportedProfileSample(
            timeSeconds: timeSeconds,
            depth: 0.0, // Would come from UNDERWATER_DEPTH if available
            temperature: null, // Would come from WATER_TEMPERATURE if available
            heartRate: hrValue.numericValue.round(),
          ),
        );
      }

      return samples;
    } catch (e) {
      return [];
    }
  }

  /// Calculate maximum depth from samples.
  double _calculateMaxDepth(List<ImportedProfileSample> samples) {
    if (samples.isEmpty) return 0.0;
    return samples.map((s) => s.depth).reduce((a, b) => a > b ? a : b);
  }

  /// Calculate average depth from samples.
  double _calculateAvgDepth(List<ImportedProfileSample> samples) {
    if (samples.isEmpty) return 0.0;
    final sum = samples.map((s) => s.depth).reduce((a, b) => a + b);
    return sum / samples.length;
  }

  /// Calculate temperature range from samples.
  ({double? min, double? max}) _calculateTemperatureRange(
    List<ImportedProfileSample> samples,
  ) {
    final temps = samples
        .map((s) => s.temperature)
        .whereType<double>()
        .toList();
    if (temps.isEmpty) return (min: null, max: null);

    return (
      min: temps.reduce((a, b) => a < b ? a : b),
      max: temps.reduce((a, b) => a > b ? a : b),
    );
  }

  /// Calculate average heart rate from samples.
  double? _calculateAvgHeartRate(List<ImportedProfileSample> samples) {
    final hrs = samples.map((s) => s.heartRate).whereType<int>().toList();
    if (hrs.isEmpty) return null;

    final sum = hrs.reduce((a, b) => a + b);
    return sum / hrs.length;
  }

  /// Extract GPS coordinates from workout metadata.
  ({double latitude, double longitude})? _extractGpsCoordinates(
    WorkoutHealthValue workout,
  ) {
    // GPS coordinates would be extracted from the workout route
    // This requires additional platform-specific code to access
    // HKWorkoutRoute samples, which isn't directly available in the
    // health package. For now, return null.
    // In a future enhancement, this could use method channels to
    // fetch the workout route from native HealthKit.
    return null;
  }
}
