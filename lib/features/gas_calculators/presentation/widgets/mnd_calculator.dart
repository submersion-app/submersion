import 'package:flutter/material.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mnd_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// MND/END (Maximum Narcotic Depth / Equivalent Narcotic Depth) calculator.
///
/// Calculates the maximum depth before narcosis exceeds a configured END limit,
/// and shows the equivalent narcotic depth at any given depth for the selected
/// gas mix.
class MndCalculator extends ConsumerWidget {
  const MndCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o2 = ref.watch(mndO2Provider);
    final he = ref.watch(mndHeProvider);
    final endLimit = ref.watch(mndEndLimitProvider);
    final o2Narcotic = ref.watch(mndO2NarcoticProvider);
    final mnd = ref.watch(mndResultProvider);
    final depth = ref.watch(mndDepthProvider);
    final endAtDepth = ref.watch(mndEndAtDepthProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isMetric = settings.depthUnit == DepthUnit.meters;
    final primaryUnit = units.depthSymbol;
    final secondaryUnit = isMetric ? 'ft' : 'm';

    // MND display values
    final isInfinite = mnd == double.infinity;
    final displayMnd = isInfinite ? 0.0 : units.convertDepth(mnd);
    final secondaryMnd = isInfinite ? 0.0 : (isMetric ? mnd * 3.28084 : mnd);

    // END at depth display values (clamp to 0 -- negative END at shallow
    // depths with helium mixes is mathematically valid but confusing to users)
    final clampedEnd = endAtDepth.clamp(0.0, double.infinity);
    final displayEnd = units.convertDepth(clampedEnd);
    final secondaryEnd = isMetric ? clampedEnd * 3.28084 : clampedEnd;

    // END limit display value (always stored in meters)
    final displayEndLimit = units.convertDepth(endLimit);

    // Depth slider display value
    final displayDepth = units.convertDepth(depth);

    // He max is constrained by O2
    final heMax = 100.0 - o2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Input card
              _buildInputCard(
                context,
                ref,
                textTheme: textTheme,
                colorScheme: colorScheme,
                o2: o2,
                he: he,
                heMax: heMax,
                endLimit: endLimit,
                displayEndLimit: displayEndLimit,
                o2Narcotic: o2Narcotic,
                primaryUnit: primaryUnit,
                convertDepth: units.convertDepth,
              ),
              const SizedBox(height: 16),

              // MND result card
              _buildMndResultCard(
                context,
                textTheme: textTheme,
                colorScheme: colorScheme,
                mnd: mnd,
                isInfinite: isInfinite,
                displayMnd: displayMnd,
                secondaryMnd: secondaryMnd,
                primaryUnit: primaryUnit,
                secondaryUnit: secondaryUnit,
              ),
              const SizedBox(height: 16),

              // END at depth card
              _buildEndAtDepthCard(
                context,
                ref,
                textTheme: textTheme,
                colorScheme: colorScheme,
                depth: depth,
                displayDepth: displayDepth,
                endAtDepth: endAtDepth,
                displayEnd: displayEnd,
                secondaryEnd: secondaryEnd,
                primaryUnit: primaryUnit,
                secondaryUnit: secondaryUnit,
                convertDepth: units.convertDepth,
              ),
              const SizedBox(height: 16),

              // Info card
              _buildInfoCard(
                context,
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Input Card
  // ===========================================================================

  Widget _buildInputCard(
    BuildContext context,
    WidgetRef ref, {
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required double o2,
    required double he,
    required double heMax,
    required double endLimit,
    required double displayEndLimit,
    required bool o2Narcotic,
    required String primaryUnit,
    required double Function(double) convertDepth,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.gasCalculators_mnd_inputParameters,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // O2% slider
            _buildSliderSection(
              context,
              label: context.l10n.gasCalculators_mnd_o2Percent,
              value: o2,
              unit: '%',
              min: 21,
              max: 100,
              divisions: 79,
              onChanged: (value) {
                ref.read(mndO2Provider.notifier).state = value;
                // Clamp He if it would exceed 100 - O2
                final currentHe = ref.read(mndHeProvider);
                final maxHe = 100.0 - value;
                if (currentHe > maxHe) {
                  ref.read(mndHeProvider.notifier).state = maxHe;
                }
              },
            ),
            const SizedBox(height: 24),

            // He% slider
            _buildSliderSection(
              context,
              label: context.l10n.gasCalculators_mnd_hePercent,
              value: he.clamp(0, heMax),
              unit: '%',
              min: 0,
              max: heMax,
              divisions: heMax.toInt().clamp(1, 79),
              onChanged: (value) {
                ref.read(mndHeProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 24),

            // END limit slider (stored in meters, displayed in user unit)
            _buildSliderSection(
              context,
              label: context.l10n.gasCalculators_mnd_endLimit,
              value: endLimit,
              displayValue: displayEndLimit,
              convertLabel: convertDepth,
              unit: primaryUnit,
              min: 20,
              max: 50,
              divisions: 30,
              onChanged: (value) {
                ref.read(mndEndLimitProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 16),

            // O2 narcotic switch
            SwitchListTile(
              title: Text(
                context.l10n.gasCalculators_mnd_o2Narcotic,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              value: o2Narcotic,
              onChanged: (value) {
                ref.read(mndO2NarcoticProvider.notifier).state = value;
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MND Result Card
  // ===========================================================================

  Widget _buildMndResultCard(
    BuildContext context, {
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required double mnd,
    required bool isInfinite,
    required double displayMnd,
    required double secondaryMnd,
    required String primaryUnit,
    required String secondaryUnit,
  }) {
    // Warning icon: check_circle if MND > 50m, info if > 30m,
    // warning if <= 30m (more He needed to go deep)
    final IconData icon;
    final Color iconColor;
    if (isInfinite || mnd > 50) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (mnd > 30) {
      icon = Icons.info;
      iconColor = colorScheme.onPrimaryContainer;
    } else {
      icon = Icons.warning;
      iconColor = Colors.orange;
    }

    return Semantics(
      label: isInfinite
          ? '${context.l10n.gasCalculators_mnd_resultTitle}: ${context.l10n.gasCalculators_mnd_unlimited}'
          : '${context.l10n.gasCalculators_mnd_resultTitle}: '
                '${displayMnd.toStringAsFixed(1)} $primaryUnit',
      child: Card(
        color: colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                context.l10n.gasCalculators_mnd_resultTitle,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isInfinite
                    ? '--'
                    : '${displayMnd.toStringAsFixed(1)} $primaryUnit',
                style: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              if (!isInfinite)
                Text(
                  '(${secondaryMnd.toStringAsFixed(0)} $secondaryUnit)',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ExcludeSemantics(child: Icon(icon, size: 32, color: iconColor)),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // END at Depth Card
  // ===========================================================================

  Widget _buildEndAtDepthCard(
    BuildContext context,
    WidgetRef ref, {
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required double depth,
    required double displayDepth,
    required double endAtDepth,
    required double displayEnd,
    required double secondaryEnd,
    required String primaryUnit,
    required String secondaryUnit,
    required double Function(double) convertDepth,
  }) {
    // Warning coloring: green if END < 30m, orange if 30-40m, red if > 40m
    final Color endColor;
    if (endAtDepth < 30) {
      endColor = Colors.green;
    } else if (endAtDepth <= 40) {
      endColor = Colors.orange;
    } else {
      endColor = Colors.red;
    }

    return Semantics(
      label:
          '${context.l10n.gasCalculators_mnd_endAtDepthTitle}: '
          '${displayEnd.toStringAsFixed(1)} $primaryUnit '
          'at depth ${displayDepth.toStringAsFixed(0)} $primaryUnit',
      child: Card(
        color: colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                context.l10n.gasCalculators_mnd_endAtDepthTitle,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),

              // Depth slider
              _buildSliderSection(
                context,
                label: context.l10n.gasCalculators_mnd_depthInput,
                value: depth,
                displayValue: displayDepth,
                convertLabel: convertDepth,
                unit: primaryUnit,
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (value) {
                  ref.read(mndDepthProvider.notifier).state = value;
                },
                onPrimaryContainer: true,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 16),

              // END result
              Text(
                '${displayEnd.toStringAsFixed(1)} $primaryUnit',
                style: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: endColor,
                ),
              ),
              Text(
                '(${secondaryEnd.toStringAsFixed(0)} $secondaryUnit)',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Info Card
  // ===========================================================================

  Widget _buildInfoCard(
    BuildContext context, {
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.gasCalculators_mnd_infoTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.gasCalculators_mnd_infoContent,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Slider Helper
  // ===========================================================================

  Widget _buildSliderSection(
    BuildContext context, {
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    double? displayValue,
    double Function(double)? convertLabel,
    bool onPrimaryContainer = false,
    ColorScheme? colorScheme,
  }) {
    final scheme = colorScheme ?? Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final shown = displayValue ?? value;

    // When rendering on a primaryContainer background, use those text colors
    final labelColor = onPrimaryContainer
        ? scheme.onPrimaryContainer
        : scheme.primary;
    final subtleColor = onPrimaryContainer
        ? scheme.onPrimaryContainer.withValues(alpha: 0.7)
        : scheme.onSurfaceVariant;

    // Displayed min/max in user units
    final String displayMin;
    final String displayMax;
    if (convertLabel != null) {
      displayMin = '${convertLabel(min).toStringAsFixed(0)}$unit';
      displayMax = '${convertLabel(max).toStringAsFixed(0)}$unit';
    } else {
      displayMin = '${min.toStringAsFixed(0)}$unit';
      displayMax = '${max.toStringAsFixed(0)}$unit';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.air, size: 20, color: labelColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: onPrimaryContainer
                        ? scheme.onPrimaryContainer
                        : null,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: onPrimaryContainer
                    ? scheme.onPrimaryContainer.withValues(alpha: 0.15)
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${shown.toStringAsFixed(0)}$unit',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: onPrimaryContainer
                ? scheme.onPrimaryContainer
                : scheme.primary,
            inactiveTrackColor: onPrimaryContainer
                ? scheme.onPrimaryContainer.withValues(alpha: 0.3)
                : scheme.surfaceContainerHighest,
            thumbColor: onPrimaryContainer
                ? scheme.onPrimaryContainer
                : scheme.primary,
            overlayColor: onPrimaryContainer
                ? scheme.onPrimaryContainer.withValues(alpha: 0.12)
                : scheme.primary.withValues(alpha: 0.12),
          ),
          child: Semantics(
            label: '$label: ${shown.toStringAsFixed(0)}$unit',
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayMin,
                style: textTheme.labelSmall?.copyWith(color: subtleColor),
              ),
              Text(
                displayMax,
                style: textTheme.labelSmall?.copyWith(color: subtleColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
