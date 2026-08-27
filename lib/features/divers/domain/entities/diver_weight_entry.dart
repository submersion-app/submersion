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
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiverWeightEntry({
    required this.id,
    required this.diverId,
    required this.measuredAt,
    required this.weightKg,
    this.heightCm,
    required this.createdAt,
    required this.updatedAt,
  });

  DiverWeightEntry copyWith({
    String? id,
    String? diverId,
    DateTime? measuredAt,
    double? weightKg,
    double? heightCm,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiverWeightEntry(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      measuredAt: measuredAt ?? this.measuredAt,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
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
    createdAt,
    updatedAt,
  ];
}
