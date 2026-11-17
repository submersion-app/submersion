import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/services/cylinder_config_applier.dart';
import 'package:submersion/features/cylinder_configs/domain/services/dive_tank_config_adapter.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/apply_configuration_confirm_dialog.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/set_weights_choice_dialog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_form_plan.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveSetUse');
const _uuid = Uuid();

/// What a set's use found and left on the three cards it reaches.
typedef SetUseCards = ({
  List<GearLink> gear,
  List<DiveWeight> weights,
  List<DiveTank> tanks,
});

/// What [useSetInSitting] changed: the gear, weights and cylinders before
/// and after, so a rule that applied a set can take it back while what it
/// left is still there (the site's location set, issue #4527).
@immutable
class SetUseResult {
  const SetUseResult({required this.before, required this.after});

  final SetUseCards before;
  final SetUseCards after;
}

/// The two questions a set's use can ask, as dialogs over the caller's
/// [BuildContext]. Built before the use starts, so the use itself holds no
/// context across its awaits; a question asked once the caller has gone
/// gets no answer, which keeps what is there. The use goes on: the card
/// that asked closing is not the diver taking the set back.
class SetUseQuestions {
  SetUseQuestions.dialogs(BuildContext context, this.units)
    : _context = context;

  final BuildContext _context;
  final UnitFormatter units;

  /// Add the set's weights, replace them, or keep the dive's.
  Future<SetWeightsChoice?> weights({
    required String setName,
    required double setTotalKg,
    required double currentTotalKg,
  }) async {
    if (!_context.mounted) return null;
    return showSetWeightsChoiceDialog(
      _context,
      setName: setName,
      setTotal: units.formatWeight(setTotalKg),
      currentTotal: units.formatWeight(currentTotalKg),
    );
  }

  /// Whether the cylinders the set would change may be replaced.
  Future<bool> cylinders({
    required String setName,
    required List<OverwriteTank> overwrites,
    required List<DiveTank> tanks,
  }) async {
    if (!_context.mounted) return false;
    return confirmCylinderOverwrites(
      _context,
      configName: setName,
      overwrites: overwrites,
      tanks: tanks,
      units: units,
    );
  }
}

/// The gear, weights and cylinders of [session] as they stand.
SetUseCards setUseCardsOf(EditSession<Dive> session) => (
  gear: session.valueOf(diveGearField),
  weights: session.valueOf(diveWeightsField),
  tanks: session.valueOf(diveTanksField),
);

/// Uses [set] on the sitting, as the old dive form did (issue #4525): the sets
/// it includes that are already on the dive are absorbed into it, its gear
/// [items] are added, then the weights and cylinders it carries.
///
/// Weights the dive already has ask whether to add the set's, replace them
/// or keep them; cylinders it would change ask before they are replaced,
/// and declining keeps the gear and weights already applied. [auto] is a
/// use nobody asked for (a site's location set): it asks nothing and
/// overwrites nothing.
///
/// Every step drops its result when the sitting has ended or is being
/// saved, or [stillWanted] says no (a site's location set, once the site
/// changed again). A use with [auto] asks none and needs none. Providers
/// are read through [read], which must outlive the widget that asked: the
/// use goes on after its card closes. Save waits for the whole use.
/// Returns what changed, or null when it stopped before the end.
Future<SetUseResult?> useSetInSitting(
  EditSession<Dive> session,
  EquipmentSet set,
  List<EquipmentItem> items, {
  required ProviderRead read,
  SetUseQuestions? questions,
  required bool auto,
  bool Function()? stillWanted,
}) {
  assert(auto || questions != null, 'A use that may ask needs its questions');
  final run = _use(questions, read, session, set, items, auto, stillWanted);
  session.track(run);
  return run;
}

Future<SetUseResult?> _use(
  SetUseQuestions? questions,
  ProviderRead read,
  EditSession<Dive> session,
  EquipmentSet set,
  List<EquipmentItem> items,
  bool auto,
  bool Function()? stillWanted,
) async {
  bool alive() =>
      !session.isDisposed && !session.isFrozen && (stillWanted?.call() ?? true);
  if (!alive()) return null;
  final before = setUseCardsOf(session);
  final covered = await _coveredByOuterSet(read, session, set);
  if (!alive()) return null;
  final absorbedWeights = await _absorbIncludedSets(read, session, set);
  if (!alive()) return null;
  await addGearToSitting(
    read,
    session,
    items,
    viaSetId: set.id,
    stillWanted: stillWanted,
  );
  if (!alive()) return null;
  SetBundle? bundle;
  try {
    bundle = await read(setBundleProvider(set.id).future);
  } catch (error, stackTrace) {
    // The gear is on; the weights and cylinders cannot be read.
    _log.warning(
      'Reading what set ${set.id} carries failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
  if (!alive()) return null;
  if (bundle != null) {
    final weightsDone = await _applyWeights(
      questions,
      session,
      set,
      bundle,
      absorbedWeights,
      auto: auto,
      covered: covered,
    );
    if (!weightsDone || !alive()) return null;
    await _applyCylinders(questions, session, set, bundle, auto: auto);
    if (!alive()) return null;
  }
  return SetUseResult(before: before, after: setUseCardsOf(session));
}

/// Whether a set already on the dive includes [set]: its lead is then
/// already counted, and adding it again would double it.
Future<bool> _coveredByOuterSet(
  ProviderRead read,
  EditSession<Dive> session,
  EquipmentSet set,
) async {
  final others = {
    for (final row in sittingGearRows(session))
      if (row.viaSetId != null && row.viaSetId != set.id) row.viaSetId!,
  };
  if (others.isEmpty) return false;
  try {
    final onDive = await read(
      equipmentSetRepositoryProvider,
    ).getAllSets(ids: others.toList());
    return onDive.any((outer) => outer.includedSetIds.contains(set.id));
  } catch (_) {
    // Sets unavailable: the question is asked as usual.
    return false;
  }
}

/// The sets [set] includes that are on the dive take its tag, so the dive
/// shows one set. Returns the weights they filled between them, or null
/// when none was on the dive.
Future<List<WeightEntryDraft>?> _absorbIncludedSets(
  ProviderRead read,
  EditSession<Dive> session,
  EquipmentSet set,
) async {
  final onDive = {for (final row in sittingGearRows(session)) ?row.viaSetId};
  final absorbed = [
    for (final id in set.includedSetIds)
      if (id != set.id && onDive.contains(id)) id,
  ];
  if (absorbed.isEmpty) return null;
  var weights = const <WeightEntryDraft>[];
  try {
    final bundles = await read(setBundleLoaderProvider).load(absorbed);
    weights = [for (final b in bundles) ...b.weights];
  } catch (_) {
    // The tags still move; the weights question is then asked as usual.
  }
  if (session.isDisposed || session.isFrozen) return weights;
  keepGearRows(session, [
    for (final row in sittingGearRows(session))
      absorbed.contains(row.viaSetId)
          ? GearProvenance(
              equipmentId: row.equipmentId,
              viaEquipmentId: row.viaEquipmentId,
              viaSetId: set.id,
            )
          : row,
  ]);
  return weights;
}

/// The set's weights, as [planSetWeights] decides. False when the sitting
/// went while the question was open.
Future<bool> _applyWeights(
  SetUseQuestions? questions,
  EditSession<Dive> session,
  EquipmentSet set,
  SetBundle bundle,
  List<WeightEntryDraft>? absorbedWeights, {
  required bool auto,
  required bool covered,
}) async {
  final onDive = session.valueOf(diveWeightsField);
  var step = planSetWeights(
    onDive: onDive,
    bundleWeights: bundle.weights,
    absorbedWeights: absorbedWeights,
    auto: auto,
    coveredByOuterSet: covered,
  );
  var add = false;
  if (step == SetWeightsStep.ask) {
    // Only a use that may ask reaches here: auto never plans to ask.
    final choice = await questions?.weights(
      setName: set.name,
      setTotalKg: bundle.totalWeightKg,
      currentTotalKg: onDive.fold<double>(0, (sum, w) => sum + w.amountKg),
    );
    if (session.isDisposed || session.isFrozen) return false;
    switch (choice) {
      case SetWeightsChoice.add:
        add = true;
        step = SetWeightsStep.fill;
      case SetWeightsChoice.replace:
        step = SetWeightsStep.replace;
      case SetWeightsChoice.keep || null:
        step = SetWeightsStep.leave;
    }
  }
  if (step != SetWeightsStep.fill && step != SetWeightsStep.replace) {
    return true;
  }
  session.set(diveWeightsField, [
    if (add) ...session.valueOf(diveWeightsField),
    ...bundle.toDiveWeights(diveId: session.stored.id, newId: _uuid.v4),
  ]);
  return true;
}

/// The set's cylinders, merged as a saved configuration is. What they would
/// change is asked first, unless [auto], which changes nothing already on
/// the dive.
Future<void> _applyCylinders(
  SetUseQuestions? questions,
  EditSession<Dive> session,
  EquipmentSet set,
  SetBundle bundle, {
  required bool auto,
}) async {
  if (bundle.cylinders.isEmpty) return;
  const adapter = DiveTankConfigAdapter();
  final tanks = session.valueOf(diveTanksField);
  var result = adapter.apply(
    tanks: tanks,
    items: bundle.cylinders,
    newId: (_) => newSittingTankId(),
  );
  if (result.overwrites.isNotEmpty && !auto) {
    final confirmed =
        await questions?.cylinders(
          setName: set.name,
          overwrites: result.overwrites,
          tanks: tanks,
        ) ??
        false;
    if (!confirmed || session.isDisposed || session.isFrozen) return;
    // Over the cylinders as they are now: one that came while the question
    // was open is kept.
    result = adapter.apply(
      tanks: session.valueOf(diveTanksField),
      items: bundle.cylinders,
      newId: (_) => newSittingTankId(),
      overwrite: true,
    );
  }
  if (!result.changed) return;
  setTanks(session, result.tanks, replaced: true);
}
