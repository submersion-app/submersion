import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/icd_calculator_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// ICD (isobaric counterdiffusion) calculator (issue #3121).
///
/// Compares a current gas (Gas A) against a gas switched to (Gas B) and
/// assesses the switch against the rule of fifths: the nitrogen fraction
/// should not rise by more than a fifth of how much the helium fraction
/// falls. The assessment can be turned off in Settings > Decompression.
class IcdCalculator extends ConsumerWidget {
  const IcdCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o2A = ref.watch(icdO2AProvider);
    final heA = ref.watch(icdHeAProvider);
    final o2B = ref.watch(icdO2BProvider);
    final heB = ref.watch(icdHeBProvider);
    final warningsEnabled = ref.watch(icdWarningsEnabledProvider);
    final result = ref.watch(icdResultProvider);
    final suggestions = ref.watch(icdFixSuggestionsProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGasCard(
                context,
                textTheme: textTheme,
                colorScheme: colorScheme,
                title: context.l10n.gasCalculators_icd_gasATitle,
                o2: o2A,
                he: heA,
                onO2Changed: (value) {
                  ref.read(icdO2AProvider.notifier).state = value;
                  final maxHe = 100.0 - value;
                  if (ref.read(icdHeAProvider) > maxHe) {
                    ref.read(icdHeAProvider.notifier).state = maxHe;
                  }
                },
                onHeChanged: (value) =>
                    ref.read(icdHeAProvider.notifier).state = value,
              ),
              const SizedBox(height: 16),
              _buildGasCard(
                context,
                textTheme: textTheme,
                colorScheme: colorScheme,
                title: context.l10n.gasCalculators_icd_gasBTitle,
                o2: o2B,
                he: heB,
                onO2Changed: (value) {
                  ref.read(icdO2BProvider.notifier).state = value;
                  final maxHe = 100.0 - value;
                  if (ref.read(icdHeBProvider) > maxHe) {
                    ref.read(icdHeBProvider.notifier).state = maxHe;
                  }
                },
                onHeChanged: (value) =>
                    ref.read(icdHeBProvider.notifier).state = value,
              ),
              const SizedBox(height: 16),
              _buildResultCard(
                context,
                ref,
                textTheme: textTheme,
                colorScheme: colorScheme,
                result: result,
                warningsEnabled: warningsEnabled,
                suggestions: suggestions,
              ),
              const SizedBox(height: 16),
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
  // Gas input card
  // ===========================================================================

  Widget _buildGasCard(
    BuildContext context, {
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required String title,
    required double o2,
    required double he,
    required ValueChanged<double> onO2Changed,
    required ValueChanged<double> onHeChanged,
  }) {
    final heMax = 100.0 - o2;
    final n2 = 100.0 - o2 - he;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildSliderSection(
              context,
              label: context.l10n.gasCalculators_icd_o2Percent,
              value: o2,
              unit: '%',
              min: 5,
              max: 100,
              divisions: 95,
              onChanged: onO2Changed,
            ),
            const SizedBox(height: 24),
            _buildSliderSection(
              context,
              label: context.l10n.gasCalculators_icd_hePercent,
              value: he.clamp(0, heMax),
              unit: '%',
              min: 0,
              max: heMax,
              divisions: heMax.toInt().clamp(1, 95),
              onChanged: onHeChanged,
            ),
            const SizedBox(height: 8),
            Text(
              '${context.l10n.gasCalculators_icd_n2Percent}: '
              '${n2.toStringAsFixed(0)}%',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Result card
  // ===========================================================================

  Widget _buildResultCard(
    BuildContext context,
    WidgetRef ref, {
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required IcdResult result,
    required bool warningsEnabled,
    required IcdFixSuggestions suggestions,
  }) {
    if (!warningsEnabled) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.gasCalculators_icd_disabledNotice,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final (icon, color, text) = switch (result.severity) {
      IcdSeverity.ok => (
        Icons.check_circle,
        Colors.green,
        context.l10n.gasCalculators_icd_ok,
      ),
      IcdSeverity.caution => (
        Icons.warning_amber,
        Colors.orange,
        context.l10n.gasCalculators_icd_caution,
      ),
      IcdSeverity.violation => (
        Icons.error,
        colorScheme.error,
        context.l10n.gasCalculators_icd_violation(
          result.n2IncreasePercent.toStringAsFixed(1),
          result.maxAllowedN2IncreasePercent.toStringAsFixed(1),
        ),
      ),
    };

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.gasCalculators_icd_resultTitle,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (result.severity != IcdSeverity.ok) ...[
              const SizedBox(height: 16),
              Text(
                context.l10n.gasCalculators_icd_suggestionsTitle,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildSuggestionRow(
                context,
                textTheme: textTheme,
                colorScheme: colorScheme,
                text: context.l10n.gasCalculators_icd_suggestionKeepA(
                  suggestions.heBKeepingGasA.toStringAsFixed(0),
                ),
                onApply: () => ref.read(icdHeBProvider.notifier).state =
                    suggestions.heBKeepingGasA,
              ),
              const SizedBox(height: 8),
              _buildSuggestionRow(
                context,
                textTheme: textTheme,
                colorScheme: colorScheme,
                text: context.l10n.gasCalculators_icd_suggestionKeepB(
                  suggestions.heAKeepingGasB.toStringAsFixed(0),
                ),
                onApply: () => ref.read(icdHeAProvider.notifier).state =
                    suggestions.heAKeepingGasB,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionRow(
    BuildContext context, {
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required String text,
    required VoidCallback onApply,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onApply,
          child: Text(context.l10n.gasCalculators_icd_applyButton),
        ),
      ],
    );
  }

  // ===========================================================================
  // Info card
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
                Expanded(
                  child: Text(
                    context.l10n.gasCalculators_icd_infoTitle,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.gasCalculators_icd_infoContent,
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
  // Slider helper
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
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.air, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${value.toStringAsFixed(0)}$unit',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: '$label: ${value.toStringAsFixed(0)}$unit',
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
