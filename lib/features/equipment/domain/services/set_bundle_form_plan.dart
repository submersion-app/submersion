import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_resolver.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// What applying a set does to the weights already on the dive form.
enum SetWeightsStep {
  /// The set carries no weights.
  none,

  /// The form has none, so the set's go in.
  fill,

  /// The form still holds exactly what an absorbed set filled in, so the
  /// picked set's take their place without a question.
  replace,

  /// The diver decides: add, replace or keep.
  ask,

  /// The weights on the form stay as they are, and nobody is asked: an
  /// automatic apply over weights the diver may have entered, or a pick
  /// whose lead the form already carries.
  leave,
}

/// Decides [SetWeightsStep] for a set whose bundle carries [bundleWeights]
/// landing on a form that holds [onDive] (issue #4525).
///
/// [absorbedWeights] is what the sets the picked set absorbs filled in
/// between them, or null when it absorbs none. [auto] is an apply nobody
/// asked for: the default set or a location match. [coveredByOuterSet]
/// says a set already on the form includes the picked one.
///
/// The question is skipped where its main answer, Add, would double lead
/// the form already carries for this set: when the form holds exactly the
/// set's weights (it was picked before), and when a set that includes it
/// is already on the form.
SetWeightsStep planSetWeights({
  required List<DiveWeight> onDive,
  required List<WeightEntryDraft> bundleWeights,
  required List<WeightEntryDraft>? absorbedWeights,
  required bool auto,
  bool coveredByOuterSet = false,
}) {
  if (bundleWeights.isEmpty) return SetWeightsStep.none;
  if (onDive.isEmpty) return SetWeightsStep.fill;
  if (coveredByOuterSet ||
      SetBundleResolver.sameWeights(onDive, bundleWeights)) {
    return SetWeightsStep.leave;
  }
  if (absorbedWeights != null &&
      absorbedWeights.isNotEmpty &&
      SetBundleResolver.sameWeights(onDive, absorbedWeights)) {
    return SetWeightsStep.replace;
  }
  return auto ? SetWeightsStep.leave : SetWeightsStep.ask;
}
