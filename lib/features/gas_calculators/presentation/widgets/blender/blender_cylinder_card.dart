import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_field_parsing.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_mix_row.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_section_title.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_menu.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlenderSectionTitle(
              context.l10n.gasCalculators_blender_startCylinder,
            ),
            BlenderMixRow(
              pressureSymbol: units.pressureSymbol,
              pressureController: startPressure,
              o2Controller: startO2,
              heController: startHe,
              onPressure: (v) =>
                  ref.read(blenderStartPressureProvider.notifier).state = units
                      .pressureToBar(pressureOrZero(v)),
              // A blank box keeps the value it had. See mixPercentOrKeep.
              onMix: () {
                final current = ref.read(blenderStartMixProvider);
                ref.read(blenderStartMixProvider.notifier).state = GasMix(
                  o2: mixPercentOrKeep(startO2.text, current.o2),
                  he: mixPercentOrKeep(startHe.text, current.he),
                );
              },
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
              onPressure: (v) =>
                  ref.read(blenderTargetPressureProvider.notifier).state = units
                      .pressureToBar(pressureOrZero(v)),
              onMix: () {
                final current = ref.read(blenderTargetMixProvider);
                ref.read(blenderTargetMixProvider.notifier).state = GasMix(
                  o2: mixPercentOrKeep(targetO2.text, current.o2),
                  he: mixPercentOrKeep(targetHe.text, current.he),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
