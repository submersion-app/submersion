import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/switch_depth_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// The "Setpoint switch depth" row of the CCR ppO2 limits dialog (issue
/// #3793): a slider over 3-30 m in 1 m steps and a compact number field that
/// also takes 0-100 m.
///
/// The value this row holds and reports is always meters; the value text and
/// the field show it in the diver's depth unit. A value outside the slider's
/// range pins the thumb at the nearest end while the field shows the real
/// value.
class CcrSwitchDepthRow extends StatefulWidget {
  const CcrSwitchDepthRow({
    super.key,
    required this.label,
    required this.hint,
    required this.meters,
    required this.units,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final double meters;
  final UnitFormatter units;
  final ValueChanged<double> onChanged;

  @override
  State<CcrSwitchDepthRow> createState() => CcrSwitchDepthRowState();
}

class CcrSwitchDepthRowState extends State<CcrSwitchDepthRow> {
  static const double _sliderMin = SettingsNotifier.ccrSwitchDepthSliderMin;
  static const double _sliderMax = SettingsNotifier.ccrSwitchDepthSliderMax;
  static final int _divisions = (_sliderMax - _sliderMin).round();

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textFor(widget.meters));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant CcrSwitchDepthRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rewrite the box only when it no longer reads as the held value, so a
    // half-typed entry survives the rebuild its own change triggers.
    final typed = _metersFromText(_controller.text);
    if (typed == null || typed != widget.meters) {
      _controller.text = _textFor(widget.meters);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _textFor(double meters) =>
      formatRoundedForInput(widget.units.convertDepth(meters), 1);

  /// The text as meters, through ccrSwitchDepthOnGrid, or null when it is blank,
  /// unreadable or outside 0-100 m.
  double? _metersFromText(String text) {
    final read = readNumber(text, allowNegative: false);
    if (read is! NumberValue) return null;
    final exact = widget.units.depthToMeters(read.value);
    // A little slack, so 328.1 ft still reads as 100 m.
    if (exact < SettingsNotifier.ccrSwitchDepthInputMin ||
        exact > SettingsNotifier.ccrSwitchDepthInputMax + 0.05) {
      return null;
    }
    return SettingsNotifier.ccrSwitchDepthOnGrid(exact);
  }

  void _onTextChanged(String text) {
    final meters = _metersFromText(text);
    if (meters != null && meters != widget.meters) widget.onChanged(meters);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) commit();
  }

  /// Settles the box: out-of-range text goes to the nearest end, anything
  /// that is not a number back to the held value. Runs on blur, and a Save
  /// button calls it first, since tapping a button on a touch screen does
  /// not take focus from the box (the last in-range prefix typed would be
  /// saved otherwise).
  void commit() {
    final read = readNumber(_controller.text, allowNegative: false);
    if (read is NumberValue) {
      final clamped = SettingsNotifier.ccrSwitchDepthOnGrid(
        widget.units.depthToMeters(read.value),
      );
      if (clamped != widget.meters) widget.onChanged(clamped);
      _controller.text = _textFor(clamped);
    } else {
      _controller.text = _textFor(widget.meters);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final units = widget.units;
    final thumb = widget.meters.clamp(_sliderMin, _sliderMax).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.hint,
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatSwitchDepth(units, widget.meters),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: widget.label,
                child: Slider(
                  value: thumb,
                  min: _sliderMin,
                  max: _sliderMax,
                  divisions: _divisions,
                  onChanged: (v) => widget.onChanged(v.roundToDouble()),
                  semanticFormatterCallback: (v) => formatSwitchDepth(units, v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: units.depthSymbol,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: numberInputFormatters(),
                textAlign: TextAlign.end,
                onChanged: _onTextChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
