import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Weight entry for a dive (supports multiple weight types per dive)
class DiveWeight extends Equatable {
  final String id;
  final String diveId;
  final WeightType weightType;
  final double amountKg;
  final String notes;

  /// The diver's own name for this weight, e.g. "Top pocket" (issue #956).
  /// Empty when unnamed; [weightType] still says where it is carried.
  final String label;

  const DiveWeight({
    required this.id,
    required this.diveId,
    required this.weightType,
    required this.amountKg,
    this.notes = '',
    this.label = '',
  });

  /// Create a copy with updated fields
  DiveWeight copyWith({
    String? id,
    String? diveId,
    WeightType? weightType,
    double? amountKg,
    String? notes,
    String? label,
  }) {
    return DiveWeight(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      weightType: weightType ?? this.weightType,
      amountKg: amountKg ?? this.amountKg,
      notes: notes ?? this.notes,
      label: label ?? this.label,
    );
  }

  @override
  List<Object?> get props => [id, diveId, weightType, amountKg, notes, label];
}
