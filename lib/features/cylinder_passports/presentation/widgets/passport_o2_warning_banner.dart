import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Rich fill in a cylinder with no current O2 clean clock (spec section 8).
/// Renders nothing when there is nothing to say.
class PassportO2WarningBanner extends ConsumerWidget {
  const PassportO2WarningBanner({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newest = ref.watch(newestFillProvider(equipmentId)).value;
    final clocks = ref.watch(serviceClockStatusesProvider(equipmentId)).value;
    final thresholds = ref.watch(exposureThresholdsProvider);
    final o2Clock = clocks?.where((c) => c.kind.id == 'o2-clean').firstOrNull;
    final warning = o2CleanWarning(
      newestO2Percent: newest?.o2Percent,
      o2CleanClock: o2Clock,
      highO2Fraction: thresholds.highO2Fraction,
    );
    if (warning == O2CleanWarning.none) return const SizedBox.shrink();
    final l10n = context.l10n;
    final o2 = '${newest!.o2Percent.round()}%';
    final swatch = StatusColors.of(context).alert;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: swatch.container,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: swatch.onContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  warning == O2CleanWarning.untracked
                      ? l10n.passport_o2Warning_untracked(o2)
                      : l10n.passport_o2Warning_overdue(o2),
                  style: TextStyle(color: swatch.onContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
