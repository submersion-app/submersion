import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/gas_switch_format.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Late and missed deco gas switches of one dive, beside the deco status
/// card (#2939). Shown only when the dive was evaluated.
class GasSwitchEfficiencyCard extends ConsumerWidget {
  const GasSwitchEfficiencyCard({super.key, required this.efficiency});

  final GasSwitchEfficiency efficiency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final onTime = efficiency.windows.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    onTime ? Icons.check_circle : Icons.timer_off_outlined,
                    size: 16,
                    color: onTime ? Colors.green : lateSwitchLegendColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.diveLog_gasSwitches_title,
                  style: textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (onTime)
              Text(l10n.diveLog_gasSwitches_onTime, style: textTheme.bodySmall)
            else ...[
              for (final window in efficiency.windows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _WindowRow(window: window, units: units),
                ),
              Text(
                l10n.diveLog_gasSwitches_total(
                  formatMinSec(efficiency.totalExtraDecoSeconds),
                ),
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.window, required this.units});

  final GasSwitchWindow window;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final ideal = units.formatDepth(window.idealDepth, decimals: 0);
    final actual = units.formatDepth(window.switchDepth, decimals: 0);
    final delay = formatMinSec(window.delaySeconds);
    final detail = window.isMissed
        ? l10n.diveLog_gasSwitches_missedRow(ideal)
        : hasDepthDelay(window)
        ? l10n.diveLog_gasSwitches_lateRow(actual, ideal, delay)
        : l10n.diveLog_gasSwitches_lateRowTime(delay, actual);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5, right: 8),
          decoration: BoxDecoration(
            color: GasColors.forMixFraction(window.fO2, window.fHe),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gasSwitchGasLabel(window.fO2, window.fHe),
                style: textTheme.bodyMedium,
              ),
              Text(detail, style: textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          l10n.diveLog_gasSwitches_extraDeco(
            formatMinSec(window.extraDecoSeconds),
          ),
          style: textTheme.labelMedium,
        ),
      ],
    );
  }
}
