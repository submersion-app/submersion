import 'package:flutter/material.dart';

/// A text controller that paints one span with an error underline: the
/// token the parser could not read. The span is set from a QueryError's
/// offset and length and cleared on the next successful parse.
class QueryErrorHighlightController extends TextEditingController {
  QueryErrorHighlightController({super.text});

  /// The underline colour; the field sets the theme's error colour.
  Color errorColor = Colors.red;

  int? _offset;
  int? _length;

  int? get errorOffset => _offset;
  int? get errorLength => _length;

  void setError({int? offset, int? length}) {
    if (_offset == offset && _length == length) return;
    _offset = offset;
    _length = length;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final offset = _offset;
    final length = _length;
    final value = text;
    if (offset == null || length == null || offset >= value.length) {
      return TextSpan(text: value, style: style);
    }
    final end = (offset + length).clamp(offset, value.length);
    final errorStyle = (style ?? const TextStyle()).copyWith(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.wavy,
      decorationColor: errorColor,
    );
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: value.substring(0, offset)),
        TextSpan(text: value.substring(offset, end), style: errorStyle),
        TextSpan(text: value.substring(end)),
      ],
    );
  }
}
