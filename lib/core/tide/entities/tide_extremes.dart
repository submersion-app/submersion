import 'package:equatable/equatable.dart';

/// The type of tidal extreme (high or low tide)
enum TideExtremeType {
  high,
  low;

  String get displayName {
    switch (this) {
      case TideExtremeType.high:
        return 'High Tide';
      case TideExtremeType.low:
        return 'Low Tide';
    }
  }

  String get shortName {
    switch (this) {
      case TideExtremeType.high:
        return 'High';
      case TideExtremeType.low:
        return 'Low';
    }
  }
}

/// Current tide state indicating direction and slack conditions
enum TideState {
  /// Water level is increasing
  rising,

  /// Water level is decreasing
  falling,

  /// At or near high tide (minimal change)
  slackHigh,

  /// At or near low tide (minimal change)
  slackLow;

  String get displayName {
    switch (this) {
      case TideState.rising:
        return 'Rising';
      case TideState.falling:
        return 'Falling';
      case TideState.slackHigh:
        return 'High Tide (Slack)';
      case TideState.slackLow:
        return 'Low Tide (Slack)';
    }
  }

  /// Whether the tide is currently at slack (near an extreme)
  bool get isSlack => this == TideState.slackHigh || this == TideState.slackLow;

  /// Whether water level is increasing
  bool get isRising => this == TideState.rising;

  /// Whether water level is decreasing
  bool get isFalling => this == TideState.falling;

  static TideState? fromString(String? value) {
    if (value == null) return null;
    return TideState.values.cast<TideState?>().firstWhere(
      (e) => e?.name.toLowerCase() == value.toLowerCase(),
      orElse: () => null,
    );
  }
}

/// Represents a tidal extreme (high or low tide).
///
/// Extremes are the turning points where the tide changes direction.
/// For dive planning, these are important as:
/// - High tide: maximum water depth, potentially stronger incoming currents before
/// - Low tide: minimum water depth, potentially stronger outgoing currents before
/// - Slack water (near extremes): minimal current, often ideal for diving
class TideExtreme extends Equatable {
  /// Whether this is a high or low tide
  final TideExtremeType type;

  /// The time of the extreme (when tide reaches max/min)
  final DateTime time;

  /// The height at the extreme in meters relative to datum
  final double heightMeters;

  const TideExtreme({
    required this.type,
    required this.time,
    required this.heightMeters,
  });

  /// Create from JSON map
  factory TideExtreme.fromJson(Map<String, dynamic> json) {
    return TideExtreme(
      type: TideExtremeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TideExtremeType.high,
      ),
      time: DateTime.fromMillisecondsSinceEpoch(
        json['time'] as int,
        isUtc: true,
      ),
      heightMeters: (json['heightMeters'] as num).toDouble(),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'time': time.millisecondsSinceEpoch,
      'heightMeters': heightMeters,
    };
  }

  /// Calculate duration until this extreme from a given time
  Duration durationFrom(DateTime from) {
    return time.difference(from);
  }

  /// Whether this extreme is in the future from a given time
  bool isFutureFrom(DateTime from) {
    return time.isAfter(from);
  }

  TideExtreme copyWith({
    TideExtremeType? type,
    DateTime? time,
    double? heightMeters,
  }) {
    return TideExtreme(
      type: type ?? this.type,
      time: time ?? this.time,
      heightMeters: heightMeters ?? this.heightMeters,
    );
  }

  @override
  List<Object?> get props => [type, time, heightMeters];

  @override
  String toString() =>
      'TideExtreme(${type.shortName} at ${time.toIso8601String()}: ${heightMeters.toStringAsFixed(2)}m)';
}

/// Summary of current tide conditions at a location
class TideStatus extends Equatable {
  /// Current tide state
  final TideState state;

  /// Current water height in meters
  final double currentHeight;

  /// The next upcoming extreme (high or low)
  final TideExtreme? nextExtreme;

  /// The previous extreme (high or low)
  final TideExtreme? previousExtreme;

  /// Rate of change in meters per hour (positive = rising)
  final double? rateOfChange;

  const TideStatus({
    required this.state,
    required this.currentHeight,
    this.nextExtreme,
    this.previousExtreme,
    this.rateOfChange,
  });

  /// Time until the next extreme
  Duration? get timeToNextExtreme {
    if (nextExtreme == null) return null;
    return nextExtreme!.durationFrom(DateTime.now());
  }

  /// Progress through current tide cycle (0.0 at previous extreme, 1.0 at next)
  double? get cycleProgress {
    if (previousExtreme == null || nextExtreme == null) return null;
    final total = nextExtreme!.time.difference(previousExtreme!.time);
    final elapsed = DateTime.now().difference(previousExtreme!.time);
    if (total.inMilliseconds == 0) return 0.0;
    return (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  TideStatus copyWith({
    TideState? state,
    double? currentHeight,
    TideExtreme? nextExtreme,
    TideExtreme? previousExtreme,
    double? rateOfChange,
  }) {
    return TideStatus(
      state: state ?? this.state,
      currentHeight: currentHeight ?? this.currentHeight,
      nextExtreme: nextExtreme ?? this.nextExtreme,
      previousExtreme: previousExtreme ?? this.previousExtreme,
      rateOfChange: rateOfChange ?? this.rateOfChange,
    );
  }

  @override
  List<Object?> get props => [
    state,
    currentHeight,
    nextExtreme,
    previousExtreme,
    rateOfChange,
  ];
}
