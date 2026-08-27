import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Altitude + water type inputs feeding the calculator's DiveEnvironment
/// (the same altitude/salinity seam the planner engine uses).
class EnvironmentInputs extends ConsumerWidget {
  const EnvironmentInputs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final altitude = ref.watch(calcAltitudeProvider);
    final waterType = ref.watch(calcWaterTypeProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextFormField(
            // Whole units only, but rendered by the locale formatter so the
            // seeded text matches what onChanged parses back.
            initialValue: altitude != null
                ? formatDecimalForInput(
                    units.convertAltitude(altitude).roundToDouble(),
                  )
                : '',
            decoration: InputDecoration(
              labelText:
                  '${context.l10n.divePlanner_label_altitude} '
                  '(${units.altitudeSymbol})',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (text) {
              final parsed = parseUserDecimal(text);
              ref.read(calcAltitudeProvider.notifier).state = parsed == null
                  ? null
                  : units.altitudeToMeters(parsed);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<WaterType?>(
            initialValue: waterType,
            decoration: InputDecoration(
              labelText: context.l10n.decoCalculator_waterType,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(context.l10n.decoCalculator_waterType_standard),
              ),
              for (final type in WaterType.values)
                DropdownMenuItem(value: type, child: Text(type.displayName)),
            ],
            onChanged: (type) =>
                ref.read(calcWaterTypeProvider.notifier).state = type,
          ),
        ),
      ],
    );
  }
}
