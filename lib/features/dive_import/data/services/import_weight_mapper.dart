import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';

/// A parsed weight map (`amount`, `type`, `notes`, `label`, as the UDDF and
/// Subsurface readers produce it) as a [DiveWeight] for [diveId].
DiveWeight weightFromImportData(
  Map<String, dynamic> data, {
  required String id,
  required String diveId,
}) => DiveWeight(
  id: id,
  diveId: diveId,
  weightType: data['type'] as WeightType? ?? WeightType.integrated,
  amountKg: data['amount'] as double? ?? 0.0,
  notes: data['notes'] as String? ?? '',
  label: normalizeWeightLabel(data['label'] as String? ?? ''),
);
