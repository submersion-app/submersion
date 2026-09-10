import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_sweep.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Exposure thresholds for service clocks, edited in the diver's units and
/// stored metric, plus the sensor summary rebuild (phase 2). Phase 3 adds
/// the condition engine toggles here.
class EquipmentConditionSettingsPage extends ConsumerStatefulWidget {
  const EquipmentConditionSettingsPage({super.key});

  @override
  ConsumerState<EquipmentConditionSettingsPage> createState() =>
      _EquipmentConditionSettingsPageState();
}

class _EquipmentConditionSettingsPageState
    extends ConsumerState<EquipmentConditionSettingsPage> {
  static const _log = LoggerService('EquipmentConditionSettingsPage');

  bool _rebuilding = false;
  int _rebuildDone = 0;
  int _rebuildTotal = 0;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 24),
          Text(
            l10n.equipmentConditionSettings_sensorHeader,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.equipmentConditionSettings_sensorHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ListTile(
            key: const Key('rebuild-sensor-summaries'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sensors),
            title: Text(l10n.equipmentConditionSettings_rebuild),
            subtitle: _rebuilding
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.equipmentConditionSettings_rebuild_progress(
                          _rebuildDone,
                          _rebuildTotal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _rebuildTotal == 0
                            ? null
                            : _rebuildDone / _rebuildTotal,
                      ),
                    ],
                  )
                : Text(l10n.equipmentConditionSettings_rebuild_subtitle),
            enabled: !_rebuilding,
            onTap: _rebuilding ? null : _rebuildSummaries,
          ),
        ],
      ),
    );
  }

  /// Forces every dive of the active diver through the sensor summary,
  /// oldest first, with the same progress and leave-to-cancel contract as
  /// the safety review's "Analyze all dives".
  ///
  /// The diver comes from the VALIDATED provider: the raw notifier starts
  /// null and fills in asynchronously, so reading it could hand the sweep
  /// a null the moment the page opened and force every diver's dives
  /// through on a shared device. A null here is the real answer for a
  /// library with no diver, whose dives carry no diver id either, and the
  /// unscoped sweep is what covers them.
  Future<void> _rebuildSummaries() async {
    setState(() {
      _rebuilding = true;
      _rebuildDone = 0;
      _rebuildTotal = 0;
    });

    final EquipmentConditionSweepResult result;
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (!mounted) return;
      result = await ref
          .read(equipmentConditionSweepProvider)
          .run(
            diverId: diverId,
            force: true,
            onProgress: (done, total) {
              if (!mounted) return;
              setState(() {
                _rebuildDone = done;
                _rebuildTotal = total;
              });
            },
            isCancelled: () => !mounted,
          );
    } catch (error, stackTrace) {
      // run() swallows per-dive failures itself, so reaching here means the
      // sweep could not start at all (no diver, no dive list, no database).
      _log.error(
        'Sensor summary rebuild failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _rebuilding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.equipmentConditionSettings_rebuild_failed),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _rebuilding = false);
    if (result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed == 0
              ? context.l10n.equipmentConditionSettings_rebuild_done
              : context.l10n.equipmentConditionSettings_rebuild_doneWithErrors(
                  result.failed,
                ),
        ),
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
  final _focus = FocusNode();
  String? _error;

  /// The text last handed to [widget.onSubmit], so the Done action (which
  /// reaches both the submit and the focus-loss path) and a tap elsewhere
  /// write once per edit.
  String? _committed;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _seed());
    _committed = _controller.text;
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_ThresholdField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seedKey != widget.seedKey) {
      _controller.text = _seed();
      _committed = _controller.text;
    }
  }

  /// One decimal, then the diver's decimal separator; a whole number reads
  /// as "10", not "10.0" (formatDecimalForInput strips the trailing zero).
  String _seed() =>
      formatDecimalForInput((widget.displayValue * 10).round() / 10);

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final text = _controller.text;
    if (text == _committed) return;
    final parsed = parseUserDecimal(text);
    if (parsed == null) {
      setState(() => _error = context.l10n.equipmentConditionSettings_invalid);
      return;
    }
    // Claim the text before awaiting so the Done action, which reaches both
    // the submit and the focus-loss path, writes once; give it back on
    // failure so the next Done or blur retries.
    final previous = _committed;
    _committed = text;
    setState(() => _error = null);
    try {
      await widget.onSubmit(parsed);
    } catch (_) {
      if (!mounted) return;
      _committed = previous;
      setState(
        () => _error = context.l10n.equipmentConditionSettings_saveFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        errorText: _error,
      ),
      onFieldSubmitted: (_) => _commit(),
    );
  }
}
