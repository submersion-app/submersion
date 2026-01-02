import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// Weight entry for a dive (supports multiple weight types per dive)
class DiveWeight extends Equatable {
  final String id;
  final String diveId;
  final WeightType weightType;
  final double amountKg;
  final String notes;

  const DiveWeight({
    required this.id,
    required this.diveId,
    required this.weightType,
    required this.amountKg,
    this.notes = '',
  });

  /// Create a copy with updated fields
  DiveWeight copyWith({
    String? id,
    String? diveId,
    WeightType? weightType,
    double? amountKg,
    String? notes,
  }) {
    return DiveWeight(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      weightType: weightType ?? this.weightType,
      amountKg: amountKg ?? this.amountKg,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [id, diveId, weightType, amountKg, notes];
}
