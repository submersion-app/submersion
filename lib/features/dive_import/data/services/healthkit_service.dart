import 'dart:io';

import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';

/// Answers "can this device do HealthKit at all", or null when unknowable.
typedef HealthDataAvailabilityProbe = Future<bool?> Function();

/// HealthKit implementation of HealthImportService for Apple platforms.
///
/// Fetches underwater diving workouts and associated data (depth, temperature,
/// heart rate) from Apple HealthKit. Only available on iOS.
class HealthKitService implements HealthImportService {
  HealthKitService({
    Health? health,
    bool? isPlatformSupported,
    HealthDataAvailabilityProbe? healthDataAvailable,
  }) : _health = health ?? Health(),
       _isPlatformSupported = isPlatformSupported ?? Platform.isIOS,
       _healthDataAvailableProbe = healthDataAvailable ?? _askPlatform;

  final Health _health;
  final bool _isPlatformSupported;
  final HealthDataAvailabilityProbe _healthDataAvailableProbe;

  /// The health plugin's own method channel.
  static const MethodChannel _pluginChannel = MethodChannel('flutter_health');

  /// Ask the platform whether HealthKit exists on this device.
  ///
  /// `Platform.isIOS` is not a capability check: it says yes on hardware with
  /// no Health app at all (iPadOS before 17). `HKHealthStore
  /// .isHealthDataAvailable()` is the honest answer, and the plugin's native
  /// side already serves it under `checkIfHealthDataAvailable` — its Dart API
  /// simply never calls it, so we go to the channel directly.
  ///
  /// Returns null when the answer cannot be obtained (channel missing, no
  /// binding in a unit test, plugin renamed the handler). Null is "unknown",
  /// never a refusal.
  static Future<bool?> _askPlatform() async {
    try {
      return await _pluginChannel.invokeMethod<bool>(
        'checkIfHealthDataAvailable',
      );
    } catch (_) {
      return null;
    }
  }

  /// True unless the platform states outright that HealthKit is unavailable.
  ///
  /// Asked once per service. Whether the hardware has HealthKit cannot change
  /// while the app runs, and every entry point below needs the answer, so the
  /// in-flight future is shared rather than re-queried four times a wizard.
  Future<bool> get _healthKitExists =>
      _healthKitExistsCache ??= _resolveHealthKitExists();

  Future<bool>? _healthKitExistsCache;

  /// Never throws, so the memoised future can never be a poisoned one.
  Future<bool> _resolveHealthKitExists() async {
    try {
      return await _healthDataAvailableProbe() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Everything we ask HealthKit for read access to.
  ///
  /// [HealthDataType.UNDERWATER_DEPTH] and [HealthDataType.WATER_TEMPERATURE]
  /// are the dive-specific series an Apple Watch Ultra records; without them
  /// an imported dive has no profile and a max depth of zero.
  ///
  /// Safe to request wholesale below iOS 16, where the plugin never registers
  /// those two. Its `requestAuthorization` logs an unknown type and moves on,
  /// leaving it out of the read set, then authorises the types it did resolve.
  /// An older device is granted workouts and heart rate as usual.
  static const List<HealthDataType> _readTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
    HealthDataType.UNDERWATER_DEPTH,
    HealthDataType.WATER_TEMPERATURE,
  ];

  /// Types used to probe permission state.
  ///
  /// Deliberately narrower than [_readTypes]. Where `requestAuthorization`
  /// shrugs an unknown type off, `hasPermissions` short-circuits the whole
  /// probe to false on one, so probing with the iOS 16+ dive types would make
  /// every pre-iOS-16 device look permanently denied.
  static const List<HealthDataType> _probeTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
  ];

  /// Widest gap between a depth sample and an auxiliary (temperature or heart
  /// rate) sample for the two to be considered contemporaneous.
  static const Duration _auxiliaryMatchWindow = Duration(seconds: 30);

  @override
  ImportSource get source => ImportSource.appleWatch;

  @override
  Future<bool> isAvailable() async =>
      _isPlatformSupported && await _healthKitExists;

  @override
  Future<HealthPermissionStatus> permissionStatus() async {
    if (!_isPlatformSupported || !await _healthKitExists) {
      return HealthPermissionStatus.unsupported;
    }

    try {
      final granted = await _health.hasPermissions(
        _probeTypes,
        permissions: _probeTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      if (granted == null) {
        // iOS never discloses read access. Not an answer, not a denial.
        return HealthPermissionStatus.undetermined;
      }
      return granted
          ? HealthPermissionStatus.granted
          : HealthPermissionStatus.denied;
    } catch (_) {
      // A failed probe is not a denial. Reporting "unsupported" here would
      // block the read, which is the exact mistake that broke this import.
      return HealthPermissionStatus.undetermined;
    }
  }

  @override
  Future<bool> hasPermissions() async =>
      await permissionStatus() == HealthPermissionStatus.granted;

  @override
  Future<bool> requestPermissions() async {
    if (!_isPlatformSupported || !await _healthKitExists) {
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
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ImportedDive>> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Only a definitive "no" stops us. An undetermined status is the normal
    // answer for a granted read on iOS, so querying is the only way to find
    // out what is actually there.
    final status = await permissionStatus();
    if (!status.canAttemptRead) {
      return [];
    }

    // Fetch workouts in the date range
    final workouts = await _fetchType(
      HealthDataType.WORKOUT,
      startDate,
      endDate,
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
  }

  @override
  Future<List<ImportedProfileSample>> fetchDiveProfile(String sourceId) async {
    // Profile data is already fetched as part of the dive
    // This method exists for lazy loading if needed in the future
    return [];
  }

  /// Read one data type, isolating its failures.
  ///
  /// The plugin queries types in a loop and rethrows, so batching types means
  /// one unsupported type (the dive series below iOS 16) or one revoked type
  /// discards every other type's samples too.
  Future<List<HealthDataPoint>> _fetchType(
    HealthDataType type,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      return await _health.getHealthDataFromTypes(
        types: [type],
        startTime: startTime,
        endTime: endTime,
      );
    } catch (_) {
      return [];
    }
  }

  /// Convert a HealthKit workout to an ImportedDive entity.
  Future<ImportedDive?> _workoutToDive(HealthDataPoint workoutPoint) async {
    if (workoutPoint.value is! WorkoutHealthValue) return null;

    final startTime = workoutPoint.dateFrom;
    final endTime = workoutPoint.dateTo;

    // Fetch associated samples for this workout time range
    final samples = await _fetchWorkoutSamples(startTime, endTime);

    // Calculate summary statistics
    final maxDepth = _calculateMaxDepth(samples);
    final avgDepth = _calculateAvgDepth(samples);
    final tempRange = _calculateTemperatureRange(samples);
    final avgHeartRate = _calculateAvgHeartRate(samples);

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
      profile: samples,
      sourceFileName: null,
      sourceFileFormat: 'healthkit',
    );
  }

  /// Build the dive profile from the depth, temperature, and heart rate
  /// series HealthKit recorded across the workout's time range.
  ///
  /// Depth drives the timeline — it is the one series that defines a dive
  /// profile. Temperature and heart rate are sampled far less often, so each
  /// depth point picks up the nearest reading within
  /// [_auxiliaryMatchWindow]. When no depth series exists (an older watch, or
  /// depth access declined) the heart rate series is used on its own so the
  /// dive still imports.
  Future<List<ImportedProfileSample>> _fetchWorkoutSamples(
    DateTime startTime,
    DateTime endTime,
  ) async {
    final depthPoints = _numericSeries(
      await _fetchType(HealthDataType.UNDERWATER_DEPTH, startTime, endTime),
    );
    final temperaturePoints = _numericSeries(
      await _fetchType(HealthDataType.WATER_TEMPERATURE, startTime, endTime),
    );
    final heartRatePoints = _numericSeries(
      await _fetchType(HealthDataType.HEART_RATE, startTime, endTime),
    );

    if (depthPoints.isEmpty) {
      return _heartRateOnlyProfile(startTime, heartRatePoints);
    }

    // Collapse to one entry per second, keeping the deepest reading. HealthKit
    // can hold several samples for the same instant across sources.
    final deepestBySecond = <int, double>{};
    for (final point in depthPoints) {
      final second = point.time.difference(startTime).inSeconds;
      if (second < 0) continue;
      final existing = deepestBySecond[second];
      if (existing == null || point.value > existing) {
        deepestBySecond[second] = point.value;
      }
    }

    final seconds = deepestBySecond.keys.toList()..sort();

    return [
      for (final second in seconds)
        ImportedProfileSample(
          timeSeconds: second,
          depth: deepestBySecond[second]!,
          temperature: _nearestValue(
            temperaturePoints,
            startTime.add(Duration(seconds: second)),
          ),
          heartRate: _nearestValue(
            heartRatePoints,
            startTime.add(Duration(seconds: second)),
          )?.round(),
        ),
    ];
  }

  /// Fallback profile for dives with no depth series: heart rate at depth 0.
  List<ImportedProfileSample> _heartRateOnlyProfile(
    DateTime startTime,
    List<_TimedValue> heartRatePoints,
  ) {
    return [
      for (final point in heartRatePoints)
        if (!point.time.isBefore(startTime))
          ImportedProfileSample(
            timeSeconds: point.time.difference(startTime).inSeconds,
            depth: 0.0,
            heartRate: point.value.round(),
          ),
    ];
  }

  /// Reduce raw data points to a time-sorted numeric series.
  List<_TimedValue> _numericSeries(List<HealthDataPoint> points) {
    final series = <_TimedValue>[
      for (final point in points)
        if (point.value is NumericHealthValue)
          _TimedValue(
            point.dateFrom,
            (point.value as NumericHealthValue).numericValue.toDouble(),
          ),
    ];
    series.sort((a, b) => a.time.compareTo(b.time));
    return series;
  }

  /// Value of the series entry closest to [at], or null when the series is
  /// empty or its closest entry is further away than [_auxiliaryMatchWindow].
  ///
  /// [series] must be sorted by time; a binary search keeps merging a
  /// thousand-sample depth series against the other series linear rather than
  /// quadratic.
  double? _nearestValue(List<_TimedValue> series, DateTime at) {
    if (series.isEmpty) return null;

    var low = 0;
    var high = series.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (series[mid].time.isBefore(at)) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    // `low` is the first entry at or after `at`; its predecessor is the last
    // entry before it. The nearest entry is one of those two.
    _TimedValue? best;
    var bestGap = _auxiliaryMatchWindow + const Duration(microseconds: 1);
    for (final index in [low - 1, low]) {
      if (index < 0 || index >= series.length) continue;
      final gap = series[index].time.difference(at).abs();
      if (gap < bestGap) {
        best = series[index];
        bestGap = gap;
      }
    }

    return best?.value;
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
}

/// A single numeric reading at a point in time.
class _TimedValue {
  const _TimedValue(this.time, this.value);

  final DateTime time;
  final double value;
}
