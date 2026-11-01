import 'package:flutter/material.dart';

final RegExp _minutesSeconds = RegExp(r'^(\d+)(?::([0-5]?\d))?$');

/// Seconds for a `minutes:seconds` text, or bare minutes; null when the
/// text is not a time ("ab", "1:60", "").
int? parseMinutesSeconds(String text) {
  final match = _minutesSeconds.firstMatch(text.trim());
  if (match == null) return null;
  final minutes = int.parse(match.group(1)!);
  final seconds = match.group(2);
  return minutes * 60 + (seconds == null ? 0 : int.parse(seconds));
}

/// `m:ss` for a count of seconds: 750 is "12:30", 67 is "1:07".
String formatMinutesSeconds(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

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
    this.suffixIcon,
  });

  final int? seconds;
  final ValueChanged<int?> onChanged;
  final VoidCallback? onSettled;
  final String label;
  final String formatErrorText;
  final String? Function(int seconds)? validator;

  /// A control at the end of the field, for another way to set the time.
  final Widget? suffixIcon;

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
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        suffixIcon: widget.suffixIcon,
      ),
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
