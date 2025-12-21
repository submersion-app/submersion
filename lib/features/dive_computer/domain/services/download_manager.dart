import '../entities/device_model.dart';

/// Progress information during dive download.
class DownloadProgress {
  /// Index of the current dive being downloaded (1-based)
  final int currentDive;

  /// Total number of dives to download
  final int totalDives;

  /// Overall progress as a percentage (0.0 - 1.0)
  final double percentage;

  /// Human-readable status message
  final String status;

  /// Current phase of the download
  final DownloadPhase phase;

  const DownloadProgress({
    required this.currentDive,
    required this.totalDives,
    required this.percentage,
    required this.status,
    required this.phase,
  });

  /// Initial progress state
  factory DownloadProgress.initial() => const DownloadProgress(
        currentDive: 0,
        totalDives: 0,
        percentage: 0.0,
        status: 'Preparing...',
        phase: DownloadPhase.initializing,
      );

  /// Create a connecting progress state
  factory DownloadProgress.connecting() => const DownloadProgress(
        currentDive: 0,
        totalDives: 0,
        percentage: 0.0,
        status: 'Connecting to device...',
        phase: DownloadPhase.connecting,
      );

  /// Create a downloading progress state
  factory DownloadProgress.downloading(int current, int total) =>
      DownloadProgress(
        currentDive: current,
        totalDives: total,
        percentage: total > 0 ? current / total : 0.0,
        status: 'Downloading dive $current of $total...',
        phase: DownloadPhase.downloading,
      );

  /// Create a complete progress state
  factory DownloadProgress.complete(int total) => DownloadProgress(
        currentDive: total,
        totalDives: total,
        percentage: 1.0,
        status: 'Download complete',
        phase: DownloadPhase.complete,
      );

  /// Whether the download is complete
  bool get isComplete => phase == DownloadPhase.complete;
}

/// Phases of the download process.
enum DownloadPhase {
  initializing,
  connecting,
  enumerating,
  downloading,
  processing,
  complete,
  error,
  cancelled,
}

/// A dive as downloaded from the dive computer.
///
/// This is the raw data structure before import into the app's database.
class DownloadedDive {
  /// Computer-assigned dive number
  final int? diveNumber;

  /// Start time of the dive
  final DateTime startTime;

  /// Total dive duration in seconds
  final int durationSeconds;

  /// Maximum depth in meters
  final double maxDepth;

  /// Average depth in meters (if available)
  final double? avgDepth;

  /// Minimum temperature in Celsius (if available)
  final double? minTemperature;

  /// Maximum temperature in Celsius (if available)
  final double? maxTemperature;

  /// Depth-time profile points
  final List<ProfileSample> profile;

  /// Tank/cylinder information
  final List<DownloadedTank> tanks;

  /// Gas switch events
  final List<GasSwitchEvent> gasSwitches;

  /// Raw fingerprint for duplicate detection
  final String? fingerprint;

  const DownloadedDive({
    this.diveNumber,
    required this.startTime,
    required this.durationSeconds,
    required this.maxDepth,
    this.avgDepth,
    this.minTemperature,
    this.maxTemperature,
    required this.profile,
    this.tanks = const [],
    this.gasSwitches = const [],
    this.fingerprint,
  });

  /// Duration as a Duration object
  Duration get duration => Duration(seconds: durationSeconds);

  /// End time of the dive
  DateTime get endTime => startTime.add(duration);
}

/// A profile sample point from the dive computer.
class ProfileSample {
  /// Time offset from dive start in seconds
  final int timeSeconds;

  /// Depth in meters
  final double depth;

  /// Temperature in Celsius (if available)
  final double? temperature;

  /// Tank pressure in bar (if available)
  final double? pressure;

  /// Tank index for pressure (0-based)
  final int? tankIndex;

  /// Heart rate in bpm (if available)
  final int? heartRate;

  /// ppO2 in bar (for CCR)
  final double? ppo2;

  /// CNS % at this point
  final double? cns;

  /// NDL in seconds (if in no-deco)
  final int? ndl;

  /// Deco ceiling in meters (if in deco)
  final double? ceiling;

  /// Ascent rate in m/min
  final double? ascentRate;

  const ProfileSample({
    required this.timeSeconds,
    required this.depth,
    this.temperature,
    this.pressure,
    this.tankIndex,
    this.heartRate,
    this.ppo2,
    this.cns,
    this.ndl,
    this.ceiling,
    this.ascentRate,
  });
}

/// Tank/cylinder information from the dive computer.
class DownloadedTank {
  /// Tank index (0-based)
  final int index;

  /// O2 percentage
  final double o2Percent;

  /// He percentage (for trimix)
  final double hePercent;

  /// Starting pressure in bar
  final double? startPressure;

  /// Ending pressure in bar
  final double? endPressure;

  /// Tank volume in liters
  final double? volumeLiters;

  const DownloadedTank({
    required this.index,
    required this.o2Percent,
    this.hePercent = 0.0,
    this.startPressure,
    this.endPressure,
    this.volumeLiters,
  });

  /// Whether this is air (21% O2)
  bool get isAir => o2Percent >= 20.5 && o2Percent <= 21.5 && hePercent == 0.0;

  /// Whether this is nitrox
  bool get isNitrox => o2Percent > 21.5 && hePercent == 0.0;

  /// Whether this is trimix
  bool get isTrimix => hePercent > 0.0;

  /// Gas mix name (e.g., "Air", "EAN32", "TMX 18/45")
  String get gasName {
    if (isAir) return 'Air';
    if (isTrimix) {
      return 'TMX ${o2Percent.round()}/${hePercent.round()}';
    }
    return 'EAN${o2Percent.round()}';
  }
}

/// A gas switch event from the dive.
class GasSwitchEvent {
  /// Time offset from dive start in seconds
  final int timeSeconds;

  /// Depth at switch in meters
  final double depth;

  /// Tank index switched to (0-based)
  final int toTankIndex;

  const GasSwitchEvent({
    required this.timeSeconds,
    required this.depth,
    required this.toTankIndex,
  });
}

/// Result of a download operation.
class DownloadResult {
  /// Whether the download completed successfully
  final bool success;

  /// List of downloaded dives
  final List<DownloadedDive> dives;

  /// Error message if download failed
  final String? errorMessage;

  /// Time taken for the download
  final Duration duration;

  /// Device fingerprint for tracking last download
  final String? fingerprint;

  const DownloadResult({
    required this.success,
    required this.dives,
    this.errorMessage,
    required this.duration,
    this.fingerprint,
  });

  /// Create a successful result
  factory DownloadResult.success(
    List<DownloadedDive> dives,
    Duration duration, {
    String? fingerprint,
  }) =>
      DownloadResult(
        success: true,
        dives: dives,
        duration: duration,
        fingerprint: fingerprint,
      );

  /// Create a failed result
  factory DownloadResult.failure(String error, Duration duration) =>
      DownloadResult(
        success: false,
        dives: [],
        errorMessage: error,
        duration: duration,
      );

  /// Number of dives downloaded
  int get diveCount => dives.length;
}

/// Abstract interface for downloading dives from connected dive computers.
abstract class DownloadManager {
  /// Stream of download progress updates
  Stream<DownloadProgress> get progress;

  /// Stream of individual dives as they are downloaded
  Stream<DownloadedDive> get dives;

  /// Current download progress
  DownloadProgress get currentProgress;

  /// Whether a download is in progress
  bool get isDownloading;

  /// Download dives from the connected device.
  ///
  /// [device] - The connected device to download from.
  /// [newDivesOnly] - If true, only download dives since last download.
  /// [sinceTimestamp] - Optional timestamp to download dives after.
  Future<DownloadResult> downloadDives({
    required DiscoveredDevice device,
    bool newDivesOnly = true,
    DateTime? sinceTimestamp,
  });

  /// Cancel an ongoing download
  Future<void> cancel();

  /// Dispose of resources
  void dispose();
}

/// Exception thrown when download fails.
class DownloadException implements Exception {
  final String message;
  final DownloadPhase phase;
  final dynamic originalError;

  const DownloadException(
    this.message, {
    this.phase = DownloadPhase.error,
    this.originalError,
  });

  @override
  String toString() => 'DownloadException: $message (phase: ${phase.name})';
}
