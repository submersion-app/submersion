import 'package:equatable/equatable.dart';

/// A single tide height prediction at a specific time.
///
/// Represents the computed water level relative to a reference datum
/// (typically Mean Sea Level or chart datum) at a given moment.
class TidePrediction extends Equatable {
  /// The time of this prediction (UTC recommended for storage)
  final DateTime time;

  /// Predicted tide height in meters relative to datum
  ///
  /// Positive values are above datum, negative below.
  /// Typical range varies by location but commonly -2m to +3m.
  final double heightMeters;

  const TidePrediction({required this.time, required this.heightMeters});

  /// Create from JSON map
  factory TidePrediction.fromJson(Map<String, dynamic> json) {
    return TidePrediction(
      time: DateTime.fromMillisecondsSinceEpoch(
        json['time'] as int,
        isUtc: true,
      ),
      heightMeters: (json['heightMeters'] as num).toDouble(),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {'time': time.millisecondsSinceEpoch, 'heightMeters': heightMeters};
  }

  TidePrediction copyWith({DateTime? time, double? heightMeters}) {
    return TidePrediction(
      time: time ?? this.time,
      heightMeters: heightMeters ?? this.heightMeters,
    );
  }

  @override
  List<Object?> get props => [time, heightMeters];

  @override
  String toString() =>
      'TidePrediction(${time.toIso8601String()}: ${heightMeters.toStringAsFixed(2)}m)';
}
