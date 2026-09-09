import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

/// A reusable weighting rig (issue #1609): a named set of weight entries the
/// diver saves from the dive editor and applies to later dives.
class WeightPreset extends Equatable {
  final String id;
  final String? diverId;
  final String displayName;
  final String notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WeightPresetEntry> entries;

  const WeightPreset({
    required this.id,
    this.diverId,
    required this.displayName,
    this.notes = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.entries = const [],
  });

  double get totalKg => entries.fold(0, (sum, e) => sum + e.amountKg);

  /// The entries as [DiveWeight] rows for a dive, with fresh ids so they are
  /// independent of the preset once applied.
  List<DiveWeight> toDiveWeights({
    required String diveId,
    required String Function() newId,
  }) => entries
      .map(
        (e) => DiveWeight(
          id: newId(),
          diveId: diveId,
          weightType: e.weightType,
          amountKg: e.amountKg,
          notes: e.notes,
        ),
      )
      .toList();

  WeightPreset copyWith({
    String? displayName,
    String? notes,
    int? sortOrder,
    DateTime? updatedAt,
    List<WeightPresetEntry>? entries,
  }) => WeightPreset(
    id: id,
    diverId: diverId,
    displayName: displayName ?? this.displayName,
    notes: notes ?? this.notes,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    entries: entries ?? this.entries,
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    displayName,
    notes,
    sortOrder,
    createdAt,
    updatedAt,
    entries,
  ];
}

/// A weight row being composed in the preset editor, before it has database
/// ids. The repository assigns the id, presetId and sortOrder on write.
typedef WeightEntryDraft = ({
  WeightType weightType,
  double amountKg,
  String notes,
});

/// One weight entry inside a [WeightPreset]. Same shape as a per-dive
/// [DiveWeight] minus the dive link.
class WeightPresetEntry extends Equatable {
  final String id;
  final String presetId;
  final WeightType weightType;
  final double amountKg;
  final String notes;
  final int sortOrder;

  const WeightPresetEntry({
    required this.id,
    required this.presetId,
    required this.weightType,
    required this.amountKg,
    this.notes = '',
    this.sortOrder = 0,
  });

  @override
  List<Object?> get props => [
    id,
    presetId,
    weightType,
    amountKg,
    notes,
    sortOrder,
  ];
}
