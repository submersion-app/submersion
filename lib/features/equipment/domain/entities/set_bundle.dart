import 'package:equatable/equatable.dart';

import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// Everything applying an equipment set puts on a dive (issue #4525): its
/// gear, the weight entries of its presets and the cylinders of its
/// configurations, each with what the sets it includes contribute first.
///
/// A resolved snapshot. Weights and cylinders are copied onto a dive; only
/// gear keeps a link back to the set.
class SetBundle extends Equatable {
  /// The set this bundle was resolved from, and the one gear is tagged with.
  final String setId;

  /// Gear ids without duplicates: included sets' first, then the set's own.
  final List<String> gearIds;

  /// One draft per weight entry, in the order they land on a dive.
  final List<WeightEntryDraft> weights;

  /// The cylinders in tank order, their `sortOrder` renumbered from zero so
  /// several configurations joined together keep their order when merged.
  final List<CylinderConfigItem> cylinders;

  const SetBundle({
    required this.setId,
    this.gearIds = const [],
    this.weights = const [],
    this.cylinders = const [],
  });

  double get totalWeightKg => weights.fold(0, (sum, w) => sum + w.amountKg);

  bool get hasGear => gearIds.isNotEmpty;

  /// True when applying the set would put nothing on a dive.
  bool get isEmpty => gearIds.isEmpty && weights.isEmpty && cylinders.isEmpty;

  /// The weights as rows for a dive, with fresh ids so they are independent
  /// of the presets once applied.
  List<DiveWeight> toDiveWeights({
    required String diveId,
    required String Function() newId,
  }) => [
    for (final w in weights)
      DiveWeight(
        id: newId(),
        diveId: diveId,
        weightType: w.weightType,
        amountKg: w.amountKg,
        notes: w.notes,
        label: w.label,
      ),
  ];

  @override
  List<Object?> get props => [setId, gearIds, weights, cylinders];
}
