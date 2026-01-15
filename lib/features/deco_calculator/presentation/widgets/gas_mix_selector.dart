import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';

/// Gas mix selector with presets and custom O2/He sliders.
class GasMixSelector extends ConsumerStatefulWidget {
  const GasMixSelector({super.key});

  @override
  ConsumerState<GasMixSelector> createState() => _GasMixSelectorState();
}

class _GasMixSelectorState extends ConsumerState<GasMixSelector> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final o2 = ref.watch(calcO2Provider);
    final he = ref.watch(calcHeProvider);
    final gasMix = ref.watch(calcGasMixProvider);
    final currentPreset = ref.watch(calcGasPresetProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.air, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Gas Mix',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                gasMix.name,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Common gas presets
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in [
              GasPreset.air,
              GasPreset.ean32,
              GasPreset.ean36,
              GasPreset.ean50,
            ])
              _buildPresetChip(preset, currentPreset),
          ],
        ),

        const SizedBox(height: 12),

        // Advanced toggle
        InkWell(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showAdvanced ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _showAdvanced ? 'Hide custom mix' : 'Custom mix / Trimix',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Advanced sliders
        if (_showAdvanced) ...[
          const SizedBox(height: 8),

          // O2 slider
          _buildGasSlider(
            context,
            label: 'O₂',
            value: o2,
            min: 18,
            max: 100,
            color: Colors.blue,
            onChanged: (value) {
              ref.read(calcO2Provider.notifier).state = value;
              // Ensure O2 + He doesn't exceed 100
              final currentHe = ref.read(calcHeProvider);
              if (value + currentHe > 100) {
                ref.read(calcHeProvider.notifier).state = 100 - value;
              }
            },
          ),

          const SizedBox(height: 16),

          // Helium slider
          _buildGasSlider(
            context,
            label: 'He',
            value: he,
            min: 0,
            max: 65,
            color: Colors.purple,
            onChanged: (value) {
              ref.read(calcHeProvider.notifier).state = value;
              // Ensure O2 + He doesn't exceed 100
              final currentO2 = ref.read(calcO2Provider);
              if (value + currentO2 > 100) {
                ref.read(calcO2Provider.notifier).state = 100 - value;
              }
            },
          ),

          const SizedBox(height: 12),

          // Gas composition summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGasPercent(context, 'O₂', o2, Colors.blue),
                _buildGasPercent(context, 'He', he, Colors.purple),
                _buildGasPercent(context, 'N₂', 100 - o2 - he, Colors.grey),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Trimix presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in [GasPreset.tmx2135, GasPreset.tmx1845])
                _buildPresetChip(preset, currentPreset),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPresetChip(GasPreset preset, GasPreset? currentPreset) {
    final isSelected = preset == currentPreset;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(preset.label),
      selected: isSelected,
      onSelected: (_) => applyGasPreset(ref, preset),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildGasSlider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: colorScheme.surfaceContainerHighest,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildGasPercent(
    BuildContext context,
    String label,
    double percent,
    Color color,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
