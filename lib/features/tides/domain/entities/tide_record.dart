import 'package:equatable/equatable.dart';

import 'package:submersion/core/tide/entities/tide_extremes.dart';

/// Recorded tide data for a dive.
///
/// Stores the tide conditions at the time of a dive, including:
/// - Current height and state (rising/falling)
/// - Nearby high and low tide information
///
/// This enables post-dive analysis of conditions and correlation with dive quality.
class TideRecord extends Equatable {
  final String id;
  final String diveId;

  /// Tide height at dive time (meters)
  final double heightMeters;

  /// Tide state at dive time
  final TideState tideState;

  /// Rate of change (meters per hour, positive = rising)
  final double? rateOfChange;

  /// Height at nearby high tide (meters)
  final double? highTideHeight;

  /// Time of nearby high tide
  final DateTime? highTideTime;

  /// Height at nearby low tide (meters)
  final double? lowTideHeight;

  /// Time of nearby low tide
  final DateTime? lowTideTime;

  final DateTime createdAt;

  const TideRecord({
    required this.id,
    required this.diveId,
    required this.heightMeters,
    required this.tideState,
    this.rateOfChange,
    this.highTideHeight,
    this.highTideTime,
    this.lowTideHeight,
    this.lowTideTime,
    required this.createdAt,
  });

  /// Create a TideRecord from a TideStatus (used when recording dive).
  factory TideRecord.fromStatus({
    required String id,
    required String diveId,
    required TideStatus status,
  }) {
    return TideRecord(
      id: id,
      diveId: diveId,
      heightMeters: status.currentHeight,
      tideState: status.state,
      rateOfChange: status.rateOfChange,
      highTideHeight: status.nextExtreme?.type == TideExtremeType.high
          ? status.nextExtreme?.heightMeters
          : status.previousExtreme?.type == TideExtremeType.high
          ? status.previousExtreme?.heightMeters
          : null,
      highTideTime: status.nextExtreme?.type == TideExtremeType.high
          ? status.nextExtreme?.time
          : status.previousExtreme?.type == TideExtremeType.high
          ? status.previousExtreme?.time
          : null,
      lowTideHeight: status.nextExtreme?.type == TideExtremeType.low
          ? status.nextExtreme?.heightMeters
          : status.previousExtreme?.type == TideExtremeType.low
          ? status.previousExtreme?.heightMeters
          : null,
      lowTideTime: status.nextExtreme?.type == TideExtremeType.low
          ? status.nextExtreme?.time
          : status.previousExtreme?.type == TideExtremeType.low
          ? status.previousExtreme?.time
          : null,
      createdAt: DateTime.now(),
    );
  }

  /// Convert to JSON map for serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'diveId': diveId,
      'heightMeters': heightMeters,
      'tideState': tideState.name,
      'rateOfChange': rateOfChange,
      'highTideHeight': highTideHeight,
      'highTideTime': highTideTime?.millisecondsSinceEpoch,
      'lowTideHeight': lowTideHeight,
      'lowTideTime': lowTideTime?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON map.
  factory TideRecord.fromJson(Map<String, dynamic> json) {
    return TideRecord(
      id: json['id'] as String,
      diveId: json['diveId'] as String,
      heightMeters: (json['heightMeters'] as num).toDouble(),
      tideState:
          TideState.fromString(json['tideState'] as String?) ??
          TideState.rising,
      rateOfChange: (json['rateOfChange'] as num?)?.toDouble(),
      highTideHeight: (json['highTideHeight'] as num?)?.toDouble(),
      highTideTime: json['highTideTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['highTideTime'] as int,
              isUtc: true,
            )
          : null,
      lowTideHeight: (json['lowTideHeight'] as num?)?.toDouble(),
      lowTideTime: json['lowTideTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['lowTideTime'] as int,
              isUtc: true,
            )
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int,
        isUtc: true,
      ),
    );
  }

  TideRecord copyWith({
    String? id,
    String? diveId,
    double? heightMeters,
    TideState? tideState,
    double? rateOfChange,
    double? highTideHeight,
    DateTime? highTideTime,
    double? lowTideHeight,
    DateTime? lowTideTime,
    DateTime? createdAt,
  }) {
    return TideRecord(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      heightMeters: heightMeters ?? this.heightMeters,
      tideState: tideState ?? this.tideState,
      rateOfChange: rateOfChange ?? this.rateOfChange,
      highTideHeight: highTideHeight ?? this.highTideHeight,
      highTideTime: highTideTime ?? this.highTideTime,
      lowTideHeight: lowTideHeight ?? this.lowTideHeight,
      lowTideTime: lowTideTime ?? this.lowTideTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Format height with unit.
  String get formattedHeight => '${heightMeters.toStringAsFixed(2)}m';

  /// Get the time to the next extreme (high or low).
  Duration? timeToNextExtreme(DateTime now) {
    final highDuration = highTideTime?.difference(now);
    final lowDuration = lowTideTime?.difference(now);

    if (highDuration != null &&
        !highDuration.isNegative &&
        (lowDuration == null ||
            lowDuration.isNegative ||
            highDuration < lowDuration)) {
      return highDuration;
    }
    if (lowDuration != null && !lowDuration.isNegative) {
      return lowDuration;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    heightMeters,
    tideState,
    rateOfChange,
    highTideHeight,
    highTideTime,
    lowTideHeight,
    lowTideTime,
    createdAt,
  ];

  @override
  String toString() =>
      'TideRecord(dive=$diveId, ${tideState.displayName}, $formattedHeight)';
}
