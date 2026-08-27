import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_field_parsing.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_mix_row.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_section_title.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The three banks the blender draws from, in fill order.
class BlenderFillGasesCard extends ConsumerWidget {
  const BlenderFillGasesCard({
    super.key,
    required this.o2Controllers,
    required this.heControllers,
  });

  final List<TextEditingController> o2Controllers;
  final List<TextEditingController> heControllers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final providers = [
      blenderFillGas1Provider,
      blenderFillGas2Provider,
      blenderFillGas3Provider,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlenderSectionTitle(context.l10n.gasCalculators_blender_fillGases),
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              BlenderMixRow(
                pressureSymbol: units.pressureSymbol,
                leading: '${i + 1}.',
                o2Controller: o2Controllers[i],
                heController: heControllers[i],
                // A blank box keeps the value it had. See mixPercentOrKeep.
                onMix: () {
                  final current = ref.read(providers[i]);
                  ref.read(providers[i].notifier).state = GasMix(
                    o2: mixPercentOrKeep(o2Controllers[i].text, current.o2),
                    he: mixPercentOrKeep(heControllers[i].text, current.he),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
