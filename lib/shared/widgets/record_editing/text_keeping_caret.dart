import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Replacing the text of a field the diver may be in.
extension TextKeepingCaret on TextEditingController {
  /// Shows [text] and keeps the caret where it was, or at the end of a
  /// shorter text. Assigning [TextEditingController.text] would throw the
  /// caret out of the field. A field with no caret is left without one.
  void replaceTextKeepingCaret(String text) {
    final selection = this.selection;
    value = TextEditingValue(
      text: text,
      selection: selection.isValid
          ? TextSelection.collapsed(
              offset: math.min(selection.extentOffset, text.length),
            )
          : selection,
    );
  }
}
