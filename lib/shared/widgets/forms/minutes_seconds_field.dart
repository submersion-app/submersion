import 'package:flutter/material.dart';

import 'package:submersion/core/utils/minutes_seconds.dart';

/// A minutes-and-seconds entry inside a [Form]. The field shows
/// [formatMinutesSeconds] of [seconds] (empty for null) and reports the
/// parsed value on every edit, null while the text does not parse. Its
/// validator returns [formatErrorText] for text that does not parse, else
/// what [validator] says about the parsed seconds. [onSettled] fires when
/// the field loses focus, for a parent that reorders on a finished edit
/// rather than on every keystroke. No strings of its own: the labels are
/// passed in.
class MinutesSecondsField extends StatefulWidget {
  const MinutesSecondsField({
    super.key,
    required this.seconds,
    required this.onChanged,
    required this.label,
    required this.formatErrorText,
    this.validator,
    this.onSettled,
  });

  final int? seconds;
  final ValueChanged<int?> onChanged;
  final VoidCallback? onSettled;
  final String label;
  final String formatErrorText;
  final String? Function(int seconds)? validator;

  @override
  State<MinutesSecondsField> createState() => _MinutesSecondsFieldState();
}

class _MinutesSecondsFieldState extends State<MinutesSecondsField> {
  late final TextEditingController _controller = TextEditingController(
    text: _text(widget.seconds),
  );

  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);

  static String _text(int? seconds) =>
      seconds == null ? '' : formatMinutesSeconds(seconds);

  void _onFocusChange() {
    if (!_focus.hasFocus) widget.onSettled?.call();
  }

  @override
  void didUpdateWidget(MinutesSecondsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A value set from outside replaces the text; the diver's own typing,
    // which already parses to the new value, is left as typed.
    if (widget.seconds != oldWidget.seconds &&
        parseMinutesSeconds(_controller.text) != widget.seconds) {
      // After the frame: a controller write here notifies the Form while
      // the parent is still building.
      final seconds = widget.seconds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.text = _text(seconds);
      });
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focus,
      decoration: InputDecoration(labelText: widget.label, isDense: true),
      keyboardType: TextInputType.datetime,
      validator: (text) {
        final seconds = parseMinutesSeconds(text ?? '');
        if (seconds == null) return widget.formatErrorText;
        return widget.validator?.call(seconds);
      },
      onChanged: (text) => widget.onChanged(parseMinutesSeconds(text)),
    );
  }
}
