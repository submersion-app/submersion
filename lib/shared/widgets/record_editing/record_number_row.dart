import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/record_field_marks.dart';
import 'package:submersion/shared/widgets/record_editing/reveal_answering.dart';

/// The stored value a number typed into a row stands for.
///
/// A number the row put on show itself stands for the value behind it,
/// which may carry more than the row can show: [onShow], the value it last
/// showed, then [stored], so typing that number back clears the change. A
/// number the diver typed stands for itself: [fromDisplay] of it.
double storedValueOfTyped(
  double typed, {
  required double? onShow,
  required double? stored,
  required double? Function(double value) shownNumber,
  required double Function(double typed) fromDisplay,
}) {
  if (onShow != null && typed == shownNumber(onShow)) return onShow;
  if (stored != null && typed == shownNumber(stored)) return stored;
  return fromDisplay(typed);
}

/// A number row of a card editor, bound to one field of the sitting.
///
/// The field holds the value in its stored unit; [toDisplay] and
/// [fromDisplay] carry it to and from the unit the diver reads. Emptying the
/// row sets the field to null.
///
/// What the diver types is what is stored, with one exception: the number
/// the row itself put on show is left as it is. A stored 1,234.5 m shown as
/// 4050 ft would read back as 1,234.44 m, and a value shown with fewer
/// decimals than it has would lose them; neither is a change the diver made.
/// Any other number is taken as typed, so 100.4 typed over 100 is kept even
/// where both show as "100", and so is 100 typed over that 100.4.
///
/// Text that is not a number never reaches the sitting. The row shows its
/// own message and tells the page's `RecordEditController`, which keeps the
/// card open and refuses to save until it is fixed, and asks the row to
/// scroll itself into view when it has had to refuse.
class RecordNumberRow<T> extends StatefulWidget {
  const RecordNumberRow({
    super.key,
    required this.session,
    required this.field,
    required this.label,
    this.suffixText,
    this.placeholder,
    this.fractionDigits = 0,
    this.toDisplay,
    this.fromDisplay,
    this.integer = false,
    this.allowNegative = true,
    this.trimZeros = false,
    this.apply,
    this.suggestion,
    this.onUnreadableChanged,
  });

  final EditSession<T> session;

  /// The value, in the unit it is stored in.
  final EditField<T, double?> field;
  final String label;
  final String? suffixText;
  final String? placeholder;

  /// How many decimals the value is shown with.
  final int fractionDigits;

  /// The stored unit to the one shown. Null when they are the same.
  final double Function(double stored)? toDisplay;

  /// The shown unit back to the stored one. Null when they are the same.
  final double Function(double shown)? fromDisplay;

  /// Whether only whole numbers are accepted.
  final bool integer;
  final bool allowNegative;

  /// Whether decimals a value does not need are left off: 18 shows as "18"
  /// and 21.4 as "21.4" at one decimal, the way a temperature reads.
  final bool trimZeros;

  /// Writes a value the diver typed, in the stored unit. Null is
  /// `session.set(field, value)`. For a value that moves others: a runtime
  /// moves the exit.
  final void Function(double? value)? apply;

  /// Offered beside the row while it differs from the row's text, as the
  /// form's rows offer a value worked out from the profile. Its value is
  /// already formatted in the diver's unit.
  final ProfileSuggestion? suggestion;

  /// Told when the row's text becomes, or stops being, unreadable. Such text
  /// never reaches the sitting, which keeps the last value that could be
  /// read; what the editor draws from the row's value can follow the text
  /// instead (issue #4527).
  final ValueChanged<bool>? onUnreadableChanged;

  @override
  State<RecordNumberRow<T>> createState() => _RecordNumberRowState<T>();
}

class _RecordNumberRowState<T> extends State<RecordNumberRow<T>>
    with
        RevealAnswering<RecordNumberRow<T>>,
        RecordFieldMarks<T, RecordNumberRow<T>> {
  late FieldTextBinding<T, double?> _binding = _bind();

  @override
  String get markCardId => widget.field.cardId;

  @override
  String get markFieldId => widget.field.id;

  /// The value whose number this row last put on show itself: the one it
  /// opened with, or one that arrived from elsewhere since. Null when that
  /// was nothing, or the diver has only typed.
  double? _onShow;

  FieldTextBinding<T, double?> _bind() {
    return FieldTextBinding<T, double?>(
      session: widget.session,
      field: widget.field,
      // The binding formats only what it is about to show.
      format: (stored) {
        _onShow = stored;
        // Read through the widget each time, so a change of unit is followed.
        return _format(stored);
      },
      parse: _parse,
      onUnreadableChanged: (unreadable) {
        reportUnreadable(unreadable);
        widget.onUnreadableChanged?.call(unreadable);
      },
      // Read through the widget each time, so a new rule is followed.
      apply: (value) {
        final apply = widget.apply;
        if (apply != null) {
          apply(value);
        } else {
          widget.session.set(widget.field, value);
        }
      },
    );
  }

  String _format(double? stored) {
    if (stored == null) return '';
    final shown = widget.toDisplay?.call(stored) ?? stored;
    return widget.trimZeros
        ? formatRoundedForInput(shown, widget.fractionDigits)
        : formatFixedForInput(shown, widget.fractionDigits);
  }

  /// The number the row shows for [stored], or null when it shows nothing.
  double? _shownNumber(double? stored) => switch (readNumber(_format(stored))) {
    NumberValue(:final value) => value,
    NumberBlank() || NumberInvalid() => null,
  };

  FieldInput<double?> _parse(String text) {
    final read = readNumber(
      text,
      integer: widget.integer,
      allowNegative: widget.allowNegative,
    );
    switch (read) {
      case NumberBlank():
        return const FieldValue(null);
      case NumberInvalid():
        return const FieldUnreadable();
      case NumberValue(value: final typed):
        return FieldValue(
          storedValueOfTyped(
            typed,
            onShow: _onShow,
            stored: widget.field.read(widget.session.stored),
            shownNumber: _shownNumber,
            fromDisplay: (shown) => widget.fromDisplay?.call(shown) ?? shown,
          ),
        );
    }
  }

  @override
  void didUpdateWidget(RecordNumberRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.field.id != widget.field.id ||
        oldWidget.field.cardId != widget.field.cardId) {
      withdrawMark(cardId: oldWidget.field.cardId, fieldId: oldWidget.field.id);
      _binding.dispose();
      _binding = _bind();
      return;
    }
    // The binding follows the sitting by itself. The text is read again
    // here only when what it would show may have changed: the unit, or how
    // the number is written.
    if (oldWidget.toDisplay != widget.toDisplay ||
        oldWidget.fromDisplay != widget.fromDisplay ||
        oldWidget.fractionDigits != widget.fractionDigits ||
        oldWidget.trimZeros != widget.trimZeros ||
        oldWidget.integer != widget.integer ||
        oldWidget.allowNegative != widget.allowNegative) {
      _binding.resync();
    }
  }

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormRow.text(
      label: widget.label,
      controller: _binding.controller,
      suffixText: widget.suffixText,
      placeholder: widget.placeholder,
      profileSuggestion: widget.suggestion,
      keyboardType: TextInputType.numberWithOptions(
        decimal: !widget.integer,
        signed: widget.allowNegative,
      ),
      inputFormatters: numberInputFormatters(),
      inputValidator: numberValidator(
        context,
        integer: widget.integer,
        allowNegative: widget.allowNegative,
      ),
    );
  }
}
