import 'package:equatable/equatable.dart';

/// A dated body-mass measurement for a diver (weight prediction, v104).
///
/// Entries form a history: the newest drives predictions and profile
/// display, while the entry nearest a dive's date calibrates that dive's
/// buoyancy observation.
class DiverWeightEntry extends Equatable {
  final String id;
  final String diverId;
  final DateTime measuredAt;
  final double weightKg;
  final double? heightCm;

  /// Measured body fat as a percentage, 3 to 60 (issue #4525). Null when
  /// not measured: the weight prediction then estimates it.
  final double? bodyFatPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiverWeightEntry({
    required this.id,
    required this.diverId,
    required this.measuredAt,
    required this.weightKg,
    this.heightCm,
    this.bodyFatPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Marks a parameter the caller did not name, so that [copyWith] can tell
  /// "leave it" from "clear it" for a value that may be taken back off.
  static const Object _unset = Object();

  /// [bodyFatPercent] is cleared by passing null and kept by leaving it
  /// out. The older optional fields keep theirs when given null.
  DiverWeightEntry copyWith({
    String? id,
    String? diverId,
    DateTime? measuredAt,
    double? weightKg,
    double? heightCm,
    Object? bodyFatPercent = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiverWeightEntry(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      measuredAt: measuredAt ?? this.measuredAt,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bodyFatPercent: identical(bodyFatPercent, _unset)
          ? this.bodyFatPercent
          : bodyFatPercent as double?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    measuredAt,
    weightKg,
    heightCm,
    bodyFatPercent,
    createdAt,
    updatedAt,
  ];
}
