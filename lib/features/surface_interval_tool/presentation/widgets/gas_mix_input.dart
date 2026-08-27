import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/si_slider_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Gas mix controls (mix name, O2 slider, He slider) for one dive.
///
/// The dive being edited is selected by the [o2Provider] and [heProvider]
/// arguments, so the same controls drive either the first or the second dive.
class GasMixInput extends ConsumerWidget {
  const GasMixInput({
    super.key,
    required this.o2Provider,
    required this.heProvider,
    required this.gasSafetyProvider,
    required this.o2SemanticsBuilder,
    required this.heSemanticsBuilder,
  });

  /// Oxygen percentage state for the dive being edited.
  final StateProvider<double> o2Provider;

  /// Helium percentage state for the dive being edited.
  final StateProvider<double> heProvider;

  /// Oxygen exposure for this dive, used to warn when the mix busts its MOD.
  final Provider<SiGasSafety> gasSafetyProvider;

  /// Builds the O2 slider's accessibility label from the formatted percentage.
  final String Function(String percent) o2SemanticsBuilder;

  /// Builds the He slider's accessibility label from the formatted percentage.
  final String Function(String percent) heSemanticsBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final o2 = ref.watch(o2Provider);
    final he = ref.watch(heProvider);
    final safety = ref.watch(gasSafetyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mix name
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.science,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.surfaceInterval_field_gasMix,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _gasName(context, o2: o2, he: he),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // O2 Slider
        SiSliderRow(
          label: context.l10n.surfaceInterval_field_o2,
          icon: Icons.bubble_chart,
          value: '${o2.toStringAsFixed(0)}%',
          slider: Semantics(
            label: o2SemanticsBuilder(o2.toStringAsFixed(0)),
            child: Slider(
              value: o2,
              min: 21,
              max: 100,
              divisions: 79,
              onChanged: (value) {
                ref.read(o2Provider.notifier).state = value;
                // Ensure O2 + He doesn't exceed 100%
                if (value + he > 100) {
                  ref.read(heProvider.notifier).state = 100 - value;
                }
              },
            ),
          ),
          minLabel: '21%',
          maxLabel: '100%',
        ),
        const SizedBox(height: 12),

        // He Slider
        SiSliderRow(
          label: context.l10n.surfaceInterval_field_he,
          icon: Icons.air,
          value: '${he.toStringAsFixed(0)}%',
          slider: Semantics(
            label: heSemanticsBuilder(he.toStringAsFixed(0)),
            child: Slider(
              value: he,
              min: 0,
              max: 79,
              divisions: 79,
              onChanged: (value) {
                ref.read(heProvider.notifier).state = value;
                // Ensure O2 + He doesn't exceed 100%
                if (o2 + value > 100) {
                  ref.read(o2Provider.notifier).state = 100 - value;
                }
              },
            ),
          ),
          minLabel: '0%',
          maxLabel: '79%',
        ),

        // Oxygen exposure warning
        if (safety.exceedsMod) ...[
          const SizedBox(height: 12),
          _ModWarning(safety: safety),
        ],
      ],
    );
  }

  /// Names the mix the way divers refer to it: Air, EANxx, or Trimix o2/he.
  String _gasName(
    BuildContext context, {
    required double o2,
    required double he,
  }) {
    if (he > 0) {
      return context.l10n.surfaceInterval_gasMix_trimix(o2.toInt(), he.toInt());
    }
    if (o2 > 21.5) {
      return context.l10n.surfaceInterval_gasMix_ean(o2.toInt());
    }
    return context.l10n.surfaceInterval_gasMix_air;
  }
}

/// Warns that the planned depth puts this mix past the diver's ppO2 ceiling.
class _ModWarning extends ConsumerWidget {
  const _ModWarning({required this.safety});

  final SiGasSafety safety;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.warning_amber,
              size: 20,
              color: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.surfaceInterval_gasWarning_modExceeded(
                safety.ppO2.toStringAsFixed(2),
                units.formatDepth(safety.depthMeters, decimals: 0),
                safety.limit.toStringAsFixed(2),
                units.formatDepth(safety.modMeters, decimals: 0),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
