import 'package:flutter/material.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_field_parsing.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_cylinder_picker.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_mix_row.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_section_title.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_menu.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(BlenderCylinderCard);

/// What is in the cylinder now, and what the diver wants in it.
class BlenderCylinderCard extends ConsumerWidget {
  const BlenderCylinderCard({
    super.key,
    required this.startPressure,
    required this.startO2,
    required this.startHe,
    required this.targetPressure,
    required this.targetO2,
    required this.targetHe,
  });

  final TextEditingController startPressure;
  final TextEditingController startO2;
  final TextEditingController startHe;
  final TextEditingController targetPressure;
  final TextEditingController targetO2;
  final TextEditingController targetHe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    // Bar fill pressures never reach four digits; psi ones commonly do (a
    // 300-bar cylinder is ~4350 psi), so the digit cap follows the diver's
    // unit rather than clipping psi at 999 (issue #1876).
    final pressureMaxIntDigits = units.settings.pressureUnit == PressureUnit.bar
        ? 3
        : 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: BlenderSectionTitle(
                    context.l10n.gasCalculators_blender_startCylinder,
                  ),
                ),
                // Flexible, so a long label or a narrow phone shortens the button
                // instead of overflowing the row.
                Flexible(
                  child: TextButton.icon(
                    key: const Key('blender-choose-cylinder'),
                    icon: const Icon(Icons.propane_tank_outlined, size: 18),
                    label: Text(
                      context.l10n.gasCalculators_blender_chooseCylinder,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _chooseCylinder(context, ref),
                  ),
                ),
              ],
            ),
            BlenderMixRow(
              pressureSymbol: units.pressureSymbol,
              pressureController: startPressure,
              o2Controller: startO2,
              heController: startHe,
              onPressure: (v) {
                final display = pressureOrKeep(v);
                if (display == null) return; // the field shows why
                ref.read(blenderStartPressureProvider.notifier).state = units
                    .pressureToBar(display);
              },
              // A blank box keeps the value it had. See mixPercentOrKeep.
              onMix: () {
                final current = ref.read(blenderStartMixProvider);
                ref.read(blenderStartMixProvider.notifier).state = GasMix(
                  o2: mixPercentOrKeep(startO2.text, current.o2),
                  he: mixPercentOrKeep(startHe.text, current.he),
                );
              },
              onSave: () => saveBlenderPreferences(ref),
              pressureMaxIntDigits: pressureMaxIntDigits,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BlenderSectionTitle(
                    context.l10n.gasCalculators_blender_targetFill,
                  ),
                ),
                MixTemplateMenu(
                  onSelected: (t) {
                    // The fields hold their own text, so a template chosen from
                    // the menu has to be written back into them or the diver
                    // sees their old mix over the new procedure.
                    targetO2.text = formatDecimalForInput(t.o2);
                    targetHe.text = formatDecimalForInput(t.he);
                  },
                ),
              ],
            ),
            BlenderMixRow(
              pressureSymbol: units.pressureSymbol,
              pressureController: targetPressure,
              o2Controller: targetO2,
              heController: targetHe,
              onPressure: (v) {
                final display = pressureOrKeep(v);
                if (display == null) return; // the field shows why
                ref.read(blenderTargetPressureProvider.notifier).state = units
                    .pressureToBar(display);
              },
              onMix: () {
                final current = ref.read(blenderTargetMixProvider);
                ref.read(blenderTargetMixProvider.notifier).state = GasMix(
                  o2: mixPercentOrKeep(targetO2.text, current.o2),
                  he: mixPercentOrKeep(targetHe.text, current.he),
                );
              },
              onSave: () => saveBlenderPreferences(ref),
              pressureMaxIntDigits: pressureMaxIntDigits,
            ),
          ],
        ),
      ),
    );
  }

  /// Choose cylinder (spec section 11): one of the diver's cylinders sets the
  /// size and, when it has a fill, the mix already in it. The start pressure
  /// is left alone: the last fill's pressure is what the cylinder held after
  /// filling, not what is in it now.
  Future<void> _chooseCylinder(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final EquipmentItem? tank;
    final CylinderFill? newest;
    try {
      tank = await showBlenderCylinderPicker(context, ref);
      // Nothing chosen, or the diver left the blender while scanning.
      if (tank == null || !context.mounted) return;
      // A scan may have just added the tag's fill, and the list is cached
      // until the fills tick arrives: re-read it so that fill counts.
      ref.invalidate(fillsForEquipmentProvider(tank.id));
      newest = await ref.read(newestFillProvider(tank.id).future);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to choose a cylinder for a blend',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gasCalculators_blender_cylinderFailed)),
      );
      return;
    }
    // The diver may have left the blender while the fill was read.
    if (!context.mounted) return;
    if (tank.volumeL case final litres?) {
      ref.read(blenderCylinderLitersProvider.notifier).state = litres;
    }
    if (newest != null) {
      ref.read(blenderStartMixProvider.notifier).state = newest.gasMix;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.gasCalculators_blender_filledFrom(
              tank.name,
              newest.gasMix.name,
            ),
          ),
        ),
      );
    }
    await saveBlenderPreferences(ref);
    if (!context.mounted) return;
    // Every field keeps its own controller, seeded once: a new epoch
    // rebuilds the blender so they show the new values.
    ref.read(blenderResetEpochProvider.notifier).state++;
  }
}
