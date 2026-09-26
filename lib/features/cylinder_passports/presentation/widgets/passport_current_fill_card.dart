import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_metrics.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/gas_percent.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest fill: mix, pressure, station, and the depth limits at the
/// diver's own ppO2 limits (spec section 8, Current fill card).
class PassportCurrentFillCard extends ConsumerWidget {
  const PassportCurrentFillCard({
    super.key,
    required this.equipmentId,
    required this.passportId,
  });

  final String equipmentId;
  final String? passportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final newest = ref.watch(newestFillProvider(equipmentId)).value;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.passport_fill_title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (newest == null)
              Text(l10n.passport_fill_none)
            else
              _FillSummary(fill: newest, units: units, settings: settings),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: passportId == null
                    ? null
                    : () => showLogFillSheet(
                        context,
                        passportId: passportId!,
                        equipmentId: equipmentId,
                      ),
                icon: const Icon(Icons.add),
                label: Text(l10n.passport_fill_log),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FillSummary extends StatelessWidget {
  const _FillSummary({
    required this.fill,
    required this.units,
    required this.settings,
  });

  final CylinderFill fill;
  final UnitFormatter units;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final limits = PassportGasLimits.compute(
      mix: fill.gasMix,
      ppO2Working: settings.ppO2MaxWorking,
      ppO2Deco: settings.ppO2MaxDeco,
      o2Narcotic: settings.o2Narcotic,
    );
    String ppo2(double v) => formatFixedForDisplay(v, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(fill.gasMix.name, style: theme.textTheme.headlineSmall),
            const SizedBox(width: 12),
            if (fill.pressureBar != null)
              Text(units.formatPressure(fill.pressureBar)),
            const Spacer(),
            FillSourceBadge(fill: fill),
          ],
        ),
        Text(units.formatDate(fill.filledAt)),
        Text(
          l10n.passport_fill_analysis(
            formatGasPercent(fill.o2Percent),
            formatGasPercent(fill.hePercent),
          ),
        ),
        if (fill.stationName != null)
          Text(l10n.passport_fill_station(fill.stationName!)),
        if (fill.analyzer != null)
          Text(l10n.passport_fill_analyzer(fill.analyzer!)),
        if (fill.temperatureC != null)
          Text(
            l10n.passport_fill_temperature(
              units.formatTemperature(fill.temperatureC),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          l10n.passport_fill_mod(
            units.formatDepth(limits.modWorkingM),
            ppo2(settings.ppO2MaxWorking),
          ),
        ),
        Text(
          l10n.passport_fill_mod(
            units.formatDepth(limits.modDecoM),
            ppo2(settings.ppO2MaxDeco),
          ),
        ),
        if (limits.endAtWorkingModM != null)
          Text(
            l10n.passport_fill_end(units.formatDepth(limits.endAtWorkingModM)),
          ),
      ],
    );
  }
}

/// Unsigned for a manual fill. PR 3 replaces this with the verification
/// badge; keeping the widget name lets that PR swap the body only.
class FillSourceBadge extends StatelessWidget {
  const FillSourceBadge({super.key, required this.fill});

  final CylinderFill fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.passport_fill_unsigned,
      child: Chip(
        label: Text(context.l10n.passport_fill_unsigned),
        avatar: const Icon(Icons.edit_note, size: 18),
        labelStyle: theme.textTheme.labelSmall,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
