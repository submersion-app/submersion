import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Exposure thresholds for service clocks, edited in the diver's units and
/// stored metric. Phase 3 adds the condition engine toggles here.
class EquipmentConditionSettingsPage extends ConsumerWidget {
  const EquipmentConditionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.equipmentConditionSettings_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.equipmentConditionSettings_thresholdsHeader,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.equipmentConditionSettings_thresholdsHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _ThresholdField(
            key: const Key('threshold-cold'),
            label: l10n.equipmentConditionSettings_coldLabel,
            suffix: units.temperatureSymbol,
            // Re-seed when the stored value or the unit changes.
            seedKey:
                '${settings.coldWaterThresholdC}-${settings.temperatureUnit}',
            displayValue: units.convertTemperature(
              settings.coldWaterThresholdC,
            ),
            onSubmit: (v) =>
                notifier.setColdWaterThresholdC(units.temperatureToCelsius(v)),
          ),
          const SizedBox(height: 12),
          _ThresholdField(
            key: const Key('threshold-deep'),
            label: l10n.equipmentConditionSettings_deepLabel,
            suffix: units.depthSymbol,
            seedKey: '${settings.deepDiveThresholdM}-${settings.depthUnit}',
            displayValue: units.convertDepth(settings.deepDiveThresholdM),
            onSubmit: (v) =>
                notifier.setDeepDiveThresholdM(units.depthToMeters(v)),
          ),
          const SizedBox(height: 12),
          _ThresholdField(
            key: const Key('threshold-o2'),
            label: l10n.equipmentConditionSettings_o2Label,
            suffix: '%',
            seedKey: '${settings.highO2ThresholdPercent}',
            displayValue: settings.highO2ThresholdPercent,
            onSubmit: notifier.setHighO2ThresholdPercent,
          ),
        ],
      ),
    );
  }
}

class _ThresholdField extends StatefulWidget {
  final String label;
  final String suffix;
  final String seedKey;
  final double displayValue;
  final Future<void> Function(double) onSubmit;

  const _ThresholdField({
    super.key,
    required this.label,
    required this.suffix,
    required this.seedKey,
    required this.displayValue,
    required this.onSubmit,
  });

  @override
  State<_ThresholdField> createState() => _ThresholdFieldState();
}

class _ThresholdFieldState extends State<_ThresholdField> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _seed());
  }

  @override
  void didUpdateWidget(_ThresholdField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seedKey != widget.seedKey) _controller.text = _seed();
  }

  /// One decimal, then the diver's decimal separator; a whole number reads
  /// as "10", not "10.0" (formatDecimalForInput strips the trailing zero).
  String _seed() =>
      formatDecimalForInput((widget.displayValue * 10).round() / 10);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = parseUserDecimal(_controller.text);
    if (parsed == null) {
      setState(() => _error = context.l10n.equipmentConditionSettings_invalid);
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        errorText: _error,
      ),
      onFieldSubmitted: (_) => _commit(),
      onEditingComplete: _commit,
    );
  }
}
