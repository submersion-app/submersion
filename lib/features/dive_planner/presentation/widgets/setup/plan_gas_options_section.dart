import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Subsurface-style "Gas options" for the Setup accordion's gas tab: Deco
/// SAC, SAC factor, problem solving time, bottom/deco ppO2 ceilings, best-mix
/// END, and the O2-narcotic switch - all per-plan, sitting alongside the
/// existing Bottom SAC and reserve controls in [PlanGasSection].
///
/// Each ppO2/O2-narcotic field is a nullable override of the app-wide
/// setting: an empty field (or, for the switch, no explicit choice) falls
/// back to the diver's global default, shown as the field's placeholder.
class PlanGasOptionsSection extends ConsumerWidget {
  const PlanGasOptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final globalPpO2Working = ref.watch(ppO2MaxWorkingProvider);
    final globalPpO2Deco = ref.watch(ppO2MaxDecoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          context.l10n.divePlanner_gasOptions_title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        PlanGasOptionNumberField(
          label: context.l10n.divePlanner_gasOptions_sacDeco,
          value: state.sacDeco != null
              ? units.convertVolume(state.sacDeco!)
              : null,
          hintValue: units.convertVolume(15),
          suffixText: units.rmvSymbol,
          decimals: 1,
          onChanged: (value) => notifier.updateGasOptions(
            sacDeco: value != null ? units.volumeToLiters(value) : null,
            clearSacDeco: value == null,
          ),
        ),
        PlanGasOptionNumberField(
          label: context.l10n.divePlanner_gasOptions_sacFactor,
          value: state.sacFactor,
          hintValue: 2.0,
          suffixText: '×',
          decimals: 1,
          onChanged: (value) =>
              notifier.updateGasOptions(sacFactor: value ?? 2.0),
        ),
        PlanGasOptionNumberField(
          label: context.l10n.divePlanner_gasOptions_problemSolvingMinutes,
          value: state.problemSolvingMinutes.toDouble(),
          hintValue: 2,
          suffixText: 'min',
          isInteger: true,
          onChanged: (value) => notifier.updateGasOptions(
            problemSolvingMinutes: (value ?? 2).round(),
          ),
        ),
        PlanGasOptionNumberField(
          label: context.l10n.divePlanner_gasOptions_ppO2Bottom,
          value: state.ppO2Bottom,
          hintValue: globalPpO2Working,
          suffixText: 'bar',
          decimals: 2,
          onChanged: (value) => notifier.updateGasOptions(
            ppO2Bottom: value,
            clearPpO2Bottom: value == null,
          ),
        ),
        PlanGasOptionNumberField(
          label: context.l10n.divePlanner_gasOptions_ppO2Deco,
          value: state.ppO2Deco,
          hintValue: globalPpO2Deco,
          suffixText: 'bar',
          decimals: 2,
          onChanged: (value) => notifier.updateGasOptions(
            ppO2Deco: value,
            clearPpO2Deco: value == null,
          ),
        ),
        PlanGasOptionNumberField(
          label: context.l10n.divePlanner_gasOptions_bestMixEnd,
          value: units.convertDepth(state.bestMixEndMeters),
          hintValue: units.convertDepth(30.0),
          suffixText: units.depthSymbol,
          decimals: 0,
          onChanged: (value) => notifier.updateGasOptions(
            bestMixEndMeters: units.depthToMeters(
              value ?? units.convertDepth(30.0),
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.divePlanner_gasOptions_o2Narcotic),
          value: state.o2Narcotic ?? settings.o2Narcotic,
          onChanged: (value) => notifier.updateGasOptions(o2Narcotic: value),
        ),
      ],
    );
  }
}

/// A compact numeric field for one Gas option. An empty field reports `null`
/// to [onChanged]; the caller decides what that means (clear an override, or
/// reset to a concrete default) - this widget only handles text <-> number.
class PlanGasOptionNumberField extends StatefulWidget {
  const PlanGasOptionNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.hintValue,
    required this.suffixText,
    required this.onChanged,
    this.decimals = 1,
    this.isInteger = false,
    this.semanticsLabel,
  });

  /// Current value in display units; null shows the hint only.
  final double? value;

  /// The effective/default value in display units, shown as a placeholder.
  final double hintValue;

  final String label;
  final String suffixText;
  final int decimals;
  final bool isInteger;
  final String? semanticsLabel;

  // Same box size as the planner altitude field. The unit sits outside
  // so every number box lines up; tweak [unitWidth] if a suffix clips.
  static const double fieldWidth = 80;
  static const double unitWidth = 48;

  /// Receives the parsed display-unit value, or null when the field is
  /// cleared.
  final ValueChanged<double?> onChanged;

  @override
  State<PlanGasOptionNumberField> createState() =>
      _PlanGasOptionNumberFieldState();
}

class _PlanGasOptionNumberFieldState extends State<PlanGasOptionNumberField> {
  late TextEditingController _controller;

  String _seed(double value) => widget.isInteger
      ? formatDecimalForInput(value.roundToDouble())
      : formatRoundedForInput(value, widget.decimals);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? _seed(widget.value!) : '',
    );
  }

  @override
  void didUpdateWidget(covariant PlanGasOptionNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final newText = widget.value != null ? _seed(widget.value!) : '';
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

  void _onChanged(String text) {
    if (text.trim().isEmpty) {
      widget.onChanged(null);
      return;
    }
    final parsed = widget.isInteger
        ? parseUserInt(text)?.toDouble()
        : parseUserDecimal(text);
    if (parsed != null) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(widget.label)),
          const SizedBox(width: 8),
          SizedBox(
            width: PlanGasOptionNumberField.fieldWidth,
            child: Semantics(
              label: widget.semanticsLabel ?? widget.label,
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  hintText: _seed(widget.hintValue),
                ),
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !widget.isInteger,
                ),
                inputFormatters: widget.isInteger
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                onChanged: _onChanged,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: PlanGasOptionNumberField.unitWidth,
            child: Text(widget.suffixText),
          ),
        ],
      ),
    );
  }
}
