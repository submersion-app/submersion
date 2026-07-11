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
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/rig_composer.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_prediction_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
