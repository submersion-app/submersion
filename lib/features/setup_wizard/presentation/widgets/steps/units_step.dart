import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/domain/unit_preset_detector.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Metric/Imperial preset with an expander for per-unit fine-tuning.
class UnitsStep extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  const UnitsStep({super.key, required this.mode});

  @override
  ConsumerState<UnitsStep> createState() => _UnitsStepState();
}

class _UnitsStepState extends ConsumerState<UnitsStep> {
  @override
  void initState() {
    super.initState();
    // First-run: preselect the preset matching the device locale, once.
    if (widget.mode == SetupWizardMode.firstRun) {
      final draft = ref.read(setupWizardProvider(widget.mode));
      if (draft.settings.unitPreset == UnitPreset.metric) {
        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        final preset = presetForLocale(locale);
        if (preset != UnitPreset.metric) {
          Future.microtask(() {
            if (mounted) {
              ref
                  .read(setupWizardProvider(widget.mode).notifier)
                  .applyUnitPreset(preset);
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final draft = ref.watch(setupWizardProvider(widget.mode));
    final notifier = ref.read(setupWizardProvider(widget.mode).notifier);
    final s = draft.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setup_units_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_units_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SegmentedButton<UnitPreset>(
            segments: [
              ButtonSegment(
                value: UnitPreset.metric,
                label: Text(l10n.setup_units_metric),
              ),
              ButtonSegment(
                value: UnitPreset.imperial,
                label: Text(l10n.setup_units_imperial),
              ),
            ],
            emptySelectionAllowed: true,
            selected: s.unitPreset == UnitPreset.custom
                ? const {}
                : {s.unitPreset},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                notifier.applyUnitPreset(selection.first);
              }
            },
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: Text(l10n.setup_units_advanced),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              _unitRow<DepthUnit>(
                label: l10n.setup_units_depth,
                keyPrefix: 'setup-unit-depth',
                values: DepthUnit.values,
                selected: s.depthUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(depthUnit: u)),
              ),
              _unitRow<TemperatureUnit>(
                label: l10n.setup_units_temperature,
                keyPrefix: 'setup-unit-temperature',
                values: TemperatureUnit.values,
                selected: s.temperatureUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(temperatureUnit: u)),
              ),
              _unitRow<PressureUnit>(
                label: l10n.setup_units_pressure,
                keyPrefix: 'setup-unit-pressure',
                values: PressureUnit.values,
                selected: s.pressureUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(pressureUnit: u)),
              ),
              _unitRow<VolumeUnit>(
                label: l10n.setup_units_volume,
                keyPrefix: 'setup-unit-volume',
                values: VolumeUnit.values,
                selected: s.volumeUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(volumeUnit: u)),
              ),
              _unitRow<WeightUnit>(
                label: l10n.setup_units_weight,
                keyPrefix: 'setup-unit-weight',
                values: WeightUnit.values,
                selected: s.weightUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(weightUnit: u)),
              ),
              _unitRow<AltitudeUnit>(
                label: l10n.setup_units_altitude,
                keyPrefix: 'setup-unit-altitude',
                values: AltitudeUnit.values,
                selected: s.altitudeUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(altitudeUnit: u)),
              ),
              _unitRow<SacUnit>(
                label: l10n.setup_units_sac,
                keyPrefix: 'setup-unit-sac',
                values: SacUnit.values,
                selected: s.sacUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(sacUnit: u)),
              ),
              _unitRow<TimeFormat>(
                label: l10n.setup_units_timeFormat,
                keyPrefix: 'setup-unit-timeformat',
                values: TimeFormat.values,
                selected: s.timeFormat,
                symbol: (u) => u.displayName,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(timeFormat: u)),
              ),
              // Five wide options; a segmented control overflows the row.
              _dropdownRow<DateFormatPreference>(
                label: l10n.setup_units_dateFormat,
                values: DateFormatPreference.values,
                selected: s.dateFormat,
                display: (u) => u.displayName,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(dateFormat: u)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitRow<T extends Enum>({
    required String label,
    required String keyPrefix,
    required List<T> values,
    required T selected,
    required String Function(T) symbol,
    required void Function(T) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SegmentedButton<T>(
            segments: [
              for (final v in values)
                ButtonSegment(
                  value: v,
                  label: Text(
                    symbol(v),
                    key: ValueKey('$keyPrefix-${_segmentKey(symbol(v))}'),
                  ),
                ),
            ],
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: (sel) => onChanged(sel.first),
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow<T extends Enum>({
    required String label,
    required List<T> values,
    required T selected,
    required String Function(T) display,
    required void Function(T) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<T>(
            value: selected,
            items: [
              for (final v in values)
                DropdownMenuItem(value: v, child: Text(display(v))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  String _segmentKey(String symbol) =>
      symbol.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
