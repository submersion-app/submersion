import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _uuid = Uuid();

/// The Weight card's id: its section's name.
final String diveWeightsCardId = DiveDetailSectionId.weights.name;

/// The dive's weights as rows. A dive stored with the old single weight and no
/// rows reads as one row with an empty id, as the old dive form showed it, so
/// opening the card changes nothing; the writer gives that row an id if the
/// diver changes it.
List<DiveWeight> _weightRows(Dive dive) {
  if (dive.weights.isNotEmpty) return dive.weights;
  final legacy = dive.weightAmount;
  if (legacy == null || legacy <= 0) return const [];
  return [
    DiveWeight(
      id: '',
      diveId: dive.id,
      weightType: dive.weightType ?? WeightType.belt,
      amountKg: legacy,
    ),
  ];
}

bool _sameWeights(List<DiveWeight> a, List<DiveWeight> b) {
  if (a.length != b.length) return false;
  final rest = [...b];
  for (final w in a) {
    if (!rest.remove(w)) return false;
  }
  return true;
}

/// The dive's weights, edited on the Weight card (issue #4527). Their order
/// carries no meaning: the writer keys them by id. Writing them clears the
/// old single weight, as every save of the dive form does, so a weight is
/// never counted twice.
final diveWeightsField = EditField<Dive, List<DiveWeight>>(
  id: 'weights',
  cardId: diveWeightsCardId,
  read: _weightRows,
  write: (dive, weights) => dive.copyWith(
    weights: weights,
    clearWeightAmount: true,
    clearWeightType: true,
  ),
  equals: _sameWeights,
);

/// How the weighting felt: correct, over or under. Not shown on the read
/// card; edited here, as on the form.
final diveWeightingFeedbackField = EditField<Dive, WeightingFeedback?>(
  id: 'weightingFeedback',
  cardId: diveWeightsCardId,
  read: (dive) => dive.weightingFeedback,
  write: (dive, value) => value == null
      ? dive.copyWith(clearWeightingFeedback: true)
      : dive.copyWith(weightingFeedback: value),
);

/// By about how much the weighting was over or under, in kilograms.
final diveWeightingFeedbackKgField = EditField<Dive, double?>(
  id: 'weightingFeedbackKg',
  cardId: diveWeightsCardId,
  read: (dive) => dive.weightingFeedbackKg,
  write: (dive, value) => value == null
      ? dive.copyWith(clearWeightingFeedbackKg: true)
      : dive.copyWith(weightingFeedbackKg: value),
);

bool _hasAmount(WeightingFeedback? feedback) =>
    feedback == WeightingFeedback.overweighted ||
    feedback == WeightingFeedback.underweighted;

/// Sets the weighting feedback. An amount belongs to over or under only:
/// correct or none clears it, and over or under gives back the stored
/// amount when the sitting has none.
void setWeightingFeedback(
  EditSession<Dive> session,
  WeightingFeedback? feedback,
) {
  if (session.isFrozen || session.isDisposed) return;
  session.set(diveWeightingFeedbackField, feedback);
  if (!_hasAmount(feedback)) {
    session.set(diveWeightingFeedbackKgField, null);
  } else if (session.valueOf(diveWeightingFeedbackKgField) == null) {
    session.set(
      diveWeightingFeedbackKgField,
      diveWeightingFeedbackKgField.read(session.stored),
    );
  }
}

/// A new weight row, as the form's "Add weight entry" makes it.
DiveWeight newSittingWeight(EditSession<Dive> session) => DiveWeight(
  id: _uuid.v4(),
  diveId: session.stored.id,
  weightType: WeightType.integrated,
  amountKg: 0,
);

/// Replaces the weights with [preset]'s, as fresh rows (issue #1609).
void applyWeightPresetInSitting(
  EditSession<Dive> session,
  WeightPreset preset,
) {
  if (session.isFrozen || session.isDisposed) return;
  session.set(
    diveWeightsField,
    preset.toDiveWeights(diveId: session.stored.id, newId: _uuid.v4),
  );
}

/// The weights and cylinders of the diver's last dive at a center replace
/// the sitting's (issue #2075), as fresh rows: the cylinders at
/// [defaultStartPressure] and 50 bar, as the form copies them. Switches on a
/// cylinder that is gone go with it ([setTanks]).
void applyLastDiveInSitting(
  EditSession<Dive> session,
  LastDiveAtCenter last, {
  required double defaultStartPressure,
}) {
  if (session.isFrozen || session.isDisposed) return;
  session.set(
    diveWeightsField,
    last.weightsForNewDive(diveId: session.stored.id, newId: _uuid.v4),
  );
  setTanks(
    session,
    last.tanksForNewDive(
      newId: _uuid.v4,
      startPressure: defaultStartPressure,
      endPressure: 50.0,
    ),
    replaced: true,
  );
}
