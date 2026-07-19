import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/buoyancy/placement_predictor.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/rig_composer.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_prediction_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/twin_summary_rows.dart';

/// The Weight Planner tool: compose a rig, get a personalized weight
/// prediction from the diver's history, and swap gear to see the change.
class WeightPlannerPage extends ConsumerStatefulWidget {
  const WeightPlannerPage({super.key});

  @override
  ConsumerState<WeightPlannerPage> createState() => _WeightPlannerPageState();
}

class _WeightPlannerPageState extends ConsumerState<WeightPlannerPage> {
  final List<EquipmentItem> _gear = [];
  final List<TankPresetEntity> _tanks = [];
  WaterType _water = WaterType.salt;
  // Committed values feed the (synthetic-profile) twin. The `_draft` fields
  // hold the in-progress slider value so the thumb/label track the drag live
  // while the simulation only re-runs on drag-end (see the sliders below).
  double _maxDepthM = 18;
  int _bottomMinutes = 45;
  double? _maxDepthDraft;
  int? _bottomMinutesDraft;
  final _bodyWeightController = TextEditingController();
  bool _bodyWeightSeeded = false;
  bool _tanksSeeded = false;
  String? _deltaText;
  Timer? _deltaTimer;

  @override
  void dispose() {
    _deltaTimer?.cancel();
    _bodyWeightController.dispose();
    super.dispose();
  }

  double get _displayDepthM => _maxDepthDraft ?? _maxDepthM;
  int get _displayBottomMinutes => _bottomMinutesDraft ?? _bottomMinutes;

  double? _bodyWeightKg(UnitFormatter units) {
    final parsed = double.tryParse(_bodyWeightController.text);
    return parsed != null ? units.weightToKg(parsed) : null;
  }

  WeightPrediction? _predict(FittedWeightModel? model, UnitFormatter units) {
    if (model == null) return null;
    final gear = <GearFeature>[for (final item in _gear) ?gearFeatureFor(item)];
    final tanks = [
      for (final preset in _tanks)
        TankSpec(
          presetName: preset.name,
          volumeL: preset.volumeLiters,
          workingPressureBar: preset.workingPressureBar,
          material: preset.material,
        ),
    ];
    return model.predict(
      RigSpec(
        gear: gear,
        tanks: tanks,
        waterType: _water,
        bodyWeightKg: _bodyWeightKg(units),
      ),
    );
  }

  List<TwinProfileSample> _squareProfile() =>
      squareDiveProfile(maxDepthM: _maxDepthM, bottomMinutes: _bottomMinutes);

  BuoyancyTwinOutcome? _buoyancyOutcome(
    FittedWeightModel? model,
    UnitFormatter units,
    Map<String, double>? placement,
  ) {
    if (model == null || _tanks.isEmpty) return null;
    final lead = _predict(model, units)?.totalKg ?? 0.0;
    if (lead <= 0) return null;
    final tanks = <TwinTankInput>[
      for (final p in _tanks)
        TwinTankInput(
          id: p.name,
          label: p.name,
          presetName: p.name,
          volumeL: p.volumeLiters,
          workingPressureBar: p.workingPressureBar,
          material: p.material,
          o2Percent: 21,
          startPressureBar: p.workingPressureBar,
          endPressureBar: BuoyancyPhysics.defaultReserveBar,
        ),
    ];
    final rig = BuoyancyTwinAssembler.composeRigTerms(
      items: _gear,
      tanks: tanks,
      model: model,
      waterType: _water,
      bodyWeightKg: _bodyWeightKg(units),
    );
    final input = TwinInput(
      profile: _squareProfile(),
      tanks: tanks,
      suit: rig.suit,
      staticTerms: rig.staticTerms,
      leadKg: lead,
      // Only belt + integrated lead is ditchable; fixed placements
      // (backplate/trim) must not inflate the droppable figure, which would
      // suppress the min-ditchable warning.
      droppableLeadKg: placement != null
          ? BuoyancyTwinAssembler.droppableLeadFromPlacement(placement)
          : lead,
      environment: DiveEnvironment.forConditions(waterType: _water),
      totalMassKg: rig.totalMassKg,
    );
    final wing = _gear
        .where((e) => e.type == EquipmentType.bcd && e.liftCapacityKg != null)
        .map((e) => e.liftCapacityKg)
        .firstOrNull;
    final result = runBuoyancyTwin(input);
    return BuoyancyTwinOutcome(
      result: result,
      outputs: TwinAnalyzer.analyze(result),
      wingLiftCapacityKg: wing,
    );
  }

  Widget _throughDivePanel(
    BuildContext context,
    UnitFormatter units,
    BuoyancyTwinOutcome outcome,
  ) {
    final theme = Theme.of(context);
    final net = outcome.outputs.verdict.netKg;
    final String verdict;
    if (net.abs() <= 0.5) {
      verdict = context.l10n.buoyancy_verdictNeutral;
    } else if (net > 0) {
      verdict = context.l10n.buoyancy_verdictBuoyant(
        units.formatDepth(outcome.outputs.verdict.anchor.depthM),
        units.formatWeight(net.abs()),
      );
    } else {
      verdict = context.l10n.buoyancy_verdictHeavy(
        units.formatDepth(outcome.outputs.verdict.anchor.depthM),
        units.formatWeight(net.abs()),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.buoyancy_throughDive,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${context.l10n.diveLog_detail_stat_maxDepth}: '
              '${units.formatDepth(_displayDepthM)}',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: _displayDepthM.clamp(5.0, 60.0),
              min: 5,
              max: 60,
              divisions: 55,
              onChanged: (v) => setState(() => _maxDepthDraft = v),
              onChangeEnd: (v) => setState(() {
                _maxDepthM = v;
                _maxDepthDraft = null;
              }),
            ),
            Text(
              '${context.l10n.diveLog_detail_stat_bottomTime}: '
              '$_displayBottomMinutes min',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: _displayBottomMinutes.toDouble().clamp(5.0, 90.0),
              min: 5,
              max: 90,
              divisions: 85,
              onChanged: (v) => setState(() => _bottomMinutesDraft = v.round()),
              onChangeEnd: (v) => setState(() {
                _bottomMinutes = v.round();
                _bottomMinutesDraft = null;
              }),
            ),
            const SizedBox(height: 8),
            Text(verdict, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            TwinSummaryRows(
              outputs: outcome.outputs,
              units: units,
              wingLiftCapacityKg: outcome.wingLiftCapacityKg,
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps a rig mutation so the delta chip shows the change it caused.
  void _mutate(UnitFormatter units, VoidCallback change) {
    final model = ref.read(weightCalibrationProvider).valueOrNull;
    final before = _predict(model, units)?.totalKg;
    setState(change);
    final after = _predict(model, units)?.totalKg;
    if (before != null && after != null && (after - before).abs() > 0.005) {
      final delta = after - before;
      _deltaTimer?.cancel();
      setState(() {
        _deltaText = '${delta >= 0 ? '+' : ''}${units.formatWeight(delta)}';
      });
      _deltaTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _deltaText = null);
      });
    }
  }

  Future<void> _saveBodyWeightToProfile(UnitFormatter units) async {
    final kg = _bodyWeightKg(units);
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (kg == null || diverId == null || !mounted) return;
    final now = DateTime.now();
    await ref
        .read(diverWeightEntryRepositoryProvider)
        .createEntry(
          DiverWeightEntry(
            id: '',
            diverId: diverId,
            measuredAt: now,
            weightKg: kg,
            createdAt: now,
            updatedAt: now,
          ),
        );
    ref.invalidate(diverWeightEntriesProvider);
  }

  String? _exposureItemId() {
    for (final item in _gear) {
      if (item.type == EquipmentType.wetsuit ||
          item.type == EquipmentType.drysuit) {
        return item.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Prefill body weight from the newest profile entry, once.
    final latestWeight = ref.watch(latestDiverWeightProvider).valueOrNull;
    if (!_bodyWeightSeeded && latestWeight != null) {
      _bodyWeightSeeded = true;
      _bodyWeightController.text = units
          .convertWeight(latestWeight.weightKg)
          .toStringAsFixed(1);
    }
    // Start with one tank once presets load.
    final presets = ref.watch(tankPresetsProvider).valueOrNull;
    if (!_tanksSeeded && presets != null && presets.isNotEmpty) {
      _tanksSeeded = true;
      _tanks.add(presets.first);
    }

    final model = ref.watch(weightCalibrationProvider).valueOrNull;
    final prediction = _predict(model, units);
    final observations =
        ref.watch(weightObservationsProvider).valueOrNull ?? const [];
    final placement = prediction != null
        ? PlacementPredictor.predict(
            totalKg: prediction.totalKg,
            observations: observations,
            exposureItemId: _exposureItemId(),
            incrementKg: settings.weightUnit == WeightUnit.kilograms
                ? 0.5
                : 0.45359237,
          )
        : null;
    // Placement (belt/integrated vs fixed) computed before the twin so its
    // droppable-lead figure can distinguish ditchable from fixed weight.
    final buoyancy = _buoyancyOutcome(model, units, placement);

    final savedWeightKg = latestWeight?.weightKg;
    final enteredKg = _bodyWeightKg(units);
    final showSave =
        enteredKg != null &&
        (savedWeightKg == null || (enteredKg - savedWeightKg).abs() > 0.05);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tools_weight_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (prediction != null)
              WeightPredictionCard(
                prediction: prediction,
                placement: placement,
                units: units,
                deltaText: _deltaText,
              )
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            const SizedBox(height: 8),
            RigComposer(
              gear: _gear,
              tanks: _tanks,
              waterType: _water,
              bodyWeightController: _bodyWeightController,
              units: units,
              showSaveBodyWeight: showSave,
              onGearAdded: (item) => _mutate(units, () => _gear.add(item)),
              onGearSetAdded: (items) => _mutate(units, () {
                for (final item in items) {
                  if (!_gear.any((g) => g.id == item.id)) {
                    _gear.add(item);
                  }
                }
              }),
              onGearRemoved: (item) => _mutate(
                units,
                () => _gear.removeWhere((g) => g.id == item.id),
              ),
              onTankAdded: (preset) => _mutate(units, () => _tanks.add(preset)),
              onTankRemoved: (index) =>
                  _mutate(units, () => _tanks.removeAt(index)),
              onTankChanged: (index, preset) =>
                  _mutate(units, () => _tanks[index] = preset),
              onWaterChanged: (water) => _mutate(units, () => _water = water),
              onSaveBodyWeight: () => _saveBodyWeightToProfile(units),
              onChanged: () => setState(() {}),
            ),
            if (buoyancy != null) ...[
              const SizedBox(height: 16),
              _throughDivePanel(context, units, buoyancy),
            ],
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.tools_weight_disclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square synthetic dive profile for the weight-planner tool: descent at
/// 18 m/min, [bottomMinutes] at [maxDepthM], ascent at 9 m/min, a 3 min stop
/// at 5 m, then the surface.
///
/// Timestamps are strictly increasing. When [maxDepthM] is at (or below) the
/// 5 m stop the ascent leg has zero duration, so its transition sample is
/// skipped -- emitting it would duplicate the previous sample's timestamp and
/// hand the simulator a zero-`dt` step.
@visibleForTesting
List<TwinProfileSample> squareDiveProfile({
  required double maxDepthM,
  required int bottomMinutes,
}) {
  final samples = <TwinProfileSample>[
    const TwinProfileSample(timestamp: 0, depthM: 0),
  ];
  var t = (maxDepthM / 18.0 * 60).round();
  samples.add(TwinProfileSample(timestamp: t, depthM: maxDepthM));
  final bottomS = bottomMinutes * 60;
  for (var s = 30; s < bottomS; s += 30) {
    samples.add(TwinProfileSample(timestamp: t + s, depthM: maxDepthM));
  }
  t += bottomS;
  samples.add(TwinProfileSample(timestamp: t, depthM: maxDepthM));
  final ascentS = ((maxDepthM - 5).clamp(0, 100) / 9.0 * 60).round();
  if (ascentS > 0) {
    t += ascentS;
    samples.add(TwinProfileSample(timestamp: t, depthM: 5));
  }
  for (var s = 30; s < 180; s += 30) {
    samples.add(TwinProfileSample(timestamp: t + s, depthM: 5));
  }
  t += 180;
  samples.add(TwinProfileSample(timestamp: t, depthM: 5));
  samples.add(TwinProfileSample(timestamp: t + 33, depthM: 0));
  return samples;
}
