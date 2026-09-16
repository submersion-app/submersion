import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/utils/number_input.dart';

/// A compact numeric row for one planner setting: the label on the left, a
/// fixed-width number box, and the unit outside the box so every row in the
/// planner lines up on the same two columns.
///
/// This is the planner's only numeric control. Rates, gradient factors and the
/// quick plan used to be sliders, which cost a diver the precision these
/// numbers need - one m/min of ascent rate is a pixel or two of travel on a
/// phone - and left three sections of one page looking like three apps.
///
/// An empty field reports `null` to [onChanged]; the caller decides what that
/// means (clear an override, or reset to a concrete default) - this widget
/// only handles text <-> number.
class PlanNumberField extends StatefulWidget {
  const PlanNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.hintValue,
    required this.suffixText,
    required this.onChanged,
    this.decimals = 1,
    this.isInteger = false,
    this.min,
    this.max,
    this.allowEmpty = true,
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

  /// Bounds of the accepted band, in display units. Text outside the band
  /// marks the box and never reaches [onChanged]; moving focus away clamps it
  /// to the nearest end, since a diver who types 99 m/min wants the fastest
  /// rate the planner allows, not a red box and no change.
  final double? min;
  final double? max;

  /// Whether an empty box is a value in its own right. Gas options use it to
  /// clear a per-plan override; a setting the plan always has (a rate, a
  /// gradient factor) sets this false, and an emptied box comes back to the
  /// value the plan still holds when focus leaves.
  final bool allowEmpty;

  final String? semanticsLabel;

  // Same box size as the planner altitude field. The unit sits outside
  // so every number box lines up; tweak [unitWidth] if a suffix clips.
  static const double fieldWidth = 80;
  static const double unitWidth = 48;

  /// Receives the parsed display-unit value, or null when the field is
  /// cleared.
  final ValueChanged<double?> onChanged;

  @override
  State<PlanNumberField> createState() => PlanNumberFieldState();
}

/// Public so a form that submits without moving focus can reach [commit]
/// through a `GlobalKey<PlanNumberFieldState>`.
class PlanNumberFieldState extends State<PlanNumberField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _outOfRange = false;

  String _seed(double value) => widget.isInteger
      ? formatDecimalForInput(value.roundToDouble())
      : formatRoundedForInput(value, widget.decimals);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? _seed(widget.value!) : '',
    );
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant PlanNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final newText = widget.value != null ? _seed(widget.value!) : '';
      if (_controller.text != newText) {
        _controller.text = newText;
        // The red border belonged to the text just replaced; a value from the
        // parent is one the plan holds. build() follows, so no setState.
        _outOfRange = false;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  double? _parse(String text) => widget.isInteger
      ? parseUserInt(text)?.toDouble()
      : parseUserDecimal(text);

  bool _inRange(double value) =>
      (widget.min == null || value >= widget.min!) &&
      (widget.max == null || value <= widget.max!);

  void _setOutOfRange(bool value) {
    if (_outOfRange != value) setState(() => _outOfRange = value);
  }

  void _onChanged(String text) {
    if (text.trim().isEmpty) {
      _setOutOfRange(false);
      widget.onChanged(null);
      return;
    }
    final parsed = _parse(text);
    // Half-typed text ("1." on the way to "1.5") is not an error yet; the
    // commit below is what decides whether it was ever a number.
    if (parsed == null) return;
    if (!_inRange(parsed)) {
      _setOutOfRange(true);
      return;
    }
    _setOutOfRange(false);
    widget.onChanged(parsed);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) commit();
  }

  /// Commits the box: out-of-range text settles on the nearest legal value,
  /// and text that is not a number at all falls back to the value the plan
  /// still holds, so no box is left showing something the plan does not have.
  ///
  /// Leaving the field does this on its own. A submit button has to call it
  /// first, because on a touch screen tapping a button does not take focus
  /// from the box.
  void commit() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      if (widget.allowEmpty || widget.value == null) return;
      _controller.text = _seed(widget.value!);
      _setOutOfRange(false);
      return;
    }

    final parsed = _parse(text);
    if (parsed == null) {
      _controller.text = widget.value != null ? _seed(widget.value!) : '';
      _setOutOfRange(false);
      return;
    }
    if (_inRange(parsed)) return;

    final clamped = parsed
        .clamp(widget.min ?? parsed, widget.max ?? parsed)
        .toDouble();
    _controller.text = _seed(clamped);
    _setOutOfRange(false);
    widget.onChanged(clamped);
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
            width: PlanNumberField.fieldWidth,
            child: Semantics(
              label: widget.semanticsLabel ?? widget.label,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  hintText: _seed(widget.hintValue),
                  // A bare red border: the row has no space for a message and
                  // an error line would shift every row below it.
                  errorText: _outOfRange ? '' : null,
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
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
            width: PlanNumberField.unitWidth,
            child: Text(widget.suffixText),
          ),
        ],
      ),
    );
  }
}
