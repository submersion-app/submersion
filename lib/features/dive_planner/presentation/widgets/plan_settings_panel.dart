import 'package:flutter/material.dart';

import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';

/// Panel for configuring dive plan settings (GF, SAC, site).
class PlanSettingsPanel extends ConsumerWidget {
  const PlanSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.settings, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  'Plan Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gradient factors row
            Row(
              children: [
                Expanded(
                  child: _GfSlider(
                    label: 'GF Low',
                    value: planState.gfLow,
                    onChanged: (value) {
                      ref
                          .read(divePlanNotifierProvider.notifier)
                          .updateGradientFactors(value, planState.gfHigh);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _GfSlider(
                    label: 'GF High',
                    value: planState.gfHigh,
                    onChanged: (value) {
                      ref
                          .read(divePlanNotifierProvider.notifier)
                          .updateGradientFactors(planState.gfLow, value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SAC rate
            Row(
              children: [
                const Text('SAC Rate:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label:
                        'SAC Rate: ${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol} per minute',
                    child: Slider(
                      value: planState.sacRate,
                      min: 8,
                      max: 30,
                      divisions: 22,
                      label:
                          '${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol}/min',
                      onChanged: (value) {
                        ref
                            .read(divePlanNotifierProvider.notifier)
                            .updateSacRate(value);
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol}/min',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Altitude for altitude diving
            _AltitudeInput(
              altitude: planState.altitude,
              units: units,
              onChanged: (value) {
                ref
                    .read(divePlanNotifierProvider.notifier)
                    .updateAltitude(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Altitude input with group indicator for altitude diving.
class _AltitudeInput extends StatefulWidget {
  final double? altitude;
  final UnitFormatter units;
  final ValueChanged<double?> onChanged;

  const _AltitudeInput({
    required this.altitude,
    required this.units,
    required this.onChanged,
  });

  @override
  State<_AltitudeInput> createState() => _AltitudeInputState();
}

class _AltitudeInputState extends State<_AltitudeInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.altitude != null
          ? widget.units.convertAltitude(widget.altitude!).toStringAsFixed(0)
          : '',
    );
  }

  @override
  void didUpdateWidget(_AltitudeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if altitude changed externally (not from typing)
    if (oldWidget.altitude != widget.altitude) {
      final newText = widget.altitude != null
          ? widget.units.convertAltitude(widget.altitude!).toStringAsFixed(0)
          : '';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final altitudeGroup = AltitudeGroup.fromAltitude(widget.altitude);
    final hasAltitude = widget.altitude != null && widget.altitude! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.terrain, size: 18),
            const SizedBox(width: 8),
            const Text('Altitude:'),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  suffixText: widget.units.altitudeSymbol,
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (value.isEmpty) {
                    widget.onChanged(null);
                  } else {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      final meters = widget.units.altitudeToMeters(parsed);
                      widget.onChanged(meters);
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            if (hasAltitude && altitudeGroup != AltitudeGroup.seaLevel)
              Semantics(
                label: 'Altitude group: ${altitudeGroup.displayName}',
                child: _buildGroupChip(theme, altitudeGroup),
              ),
          ],
        ),
        if (hasAltitude && altitudeGroup != AltitudeGroup.seaLevel)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 26),
            child: Text(
              altitudeGroup.rangeDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getGroupColor(theme, altitudeGroup),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGroupChip(ThemeData theme, AltitudeGroup group) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getGroupColor(theme, group).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _getGroupColor(theme, group).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        group.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: _getGroupColor(theme, group),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getGroupColor(ThemeData theme, AltitudeGroup group) {
    switch (group.warningLevel) {
      case AltitudeWarningLevel.none:
        return theme.colorScheme.onSurface;
      case AltitudeWarningLevel.info:
        return Colors.blue;
      case AltitudeWarningLevel.caution:
        return Colors.orange;
      case AltitudeWarningLevel.warning:
        return Colors.deepOrange;
      case AltitudeWarningLevel.severe:
        return Colors.red;
    }
  }
}

class _GfSlider extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _GfSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: '$label: $value%',
                child: Slider(
                  value: value.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '$value%',
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ),
            SizedBox(
              width: 45,
              child: Text(
                '$value%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
