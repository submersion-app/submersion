import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// A number row of a card editor, bound to one field of the sitting.
///
/// The field holds the value in its stored unit; [toDisplay] and
/// [fromDisplay] carry it to and from the unit the diver reads. Emptying the
/// row sets the field to null.
///
/// What the diver types is what is stored, with one exception: the number
/// the row is already showing is left as it is. A stored 1,234.5 m shown as
/// 4050 ft would read back as 1,234.44 m, and a value shown with fewer
/// decimals than it has would lose them; neither is a change the diver made.
/// Any other number is taken as typed, so 100.4 typed over 100 is kept even
/// where both show as "100".
///
/// Text that is not a number never reaches the sitting. The row shows its
/// own message and tells the page's [RecordEditController], which keeps the
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

  @override
  State<RecordNumberRow<T>> createState() => _RecordNumberRowState<T>();
}

class _RecordNumberRowState<T> extends State<RecordNumberRow<T>> {
  late FieldTextBinding<T, double?> _binding = _bind();

  /// The page's controller, kept so the mark can be cleared in [dispose].
  RecordEditController<T>? _controller;

  /// The last request to show itself this row answered.
  int _answeredSerial = 0;

  FieldTextBinding<T, double?> _bind() {
    return FieldTextBinding<T, double?>(
      session: widget.session,
      field: widget.field,
      // Read through the widget each time, so a change of unit is followed.
      format: _format,
      parse: _parse,
      onUnreadableChanged: _report,
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
        // The number already on show stands for the value behind it, which
        // may carry more than the row can show: the sitting's value first,
        // then the stored one, so typing that back clears the change.
        final session = widget.session;
        final current = session.valueOf(widget.field);
        if (current != null && typed == _shownNumber(current)) {
          return FieldValue(current);
        }
        final stored = widget.field.read(session.stored);
        if (stored != null && typed == _shownNumber(stored)) {
          return FieldValue(stored);
        }
        return FieldValue(widget.fromDisplay?.call(typed) ?? typed);
    }
  }

  void _report(bool unreadable) {
    _controller?.setFieldInvalid(
      widget.field.cardId,
      widget.field.id,
      invalid: unreadable,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = RecordEditScope.maybeOf<T>(context);
    _controller = controller;
    _answerReveal(controller);
  }

  /// Scrolls this row into view when the controller asks for its field: a
  /// Done or a Save was refused because its text cannot be read.
  void _answerReveal(RecordEditController<T>? controller) {
    final request = controller?.revealRequest;
    if (controller == null || request == null) return;
    if (request.cardId != widget.field.cardId ||
        request.fieldId != widget.field.id ||
        request.serial == _answeredSerial) {
      return;
    }
    _answeredSerial = request.serial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.revealHandled(request.serial);
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  @override
  void didUpdateWidget(RecordNumberRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.field.id != widget.field.id ||
        oldWidget.field.cardId != widget.field.cardId) {
      _clearMark(oldWidget);
      _binding.dispose();
      _binding = _bind();
      return;
    }
    // The unit or the number of decimals may have changed.
    _binding.resync();
  }

  /// Withdraws this row's unreadable mark, as reported for [row]'s field.
  void _clearMark(RecordNumberRow<T> row) {
    if (!_binding.isUnreadable) return;
    _controller?.setFieldInvalid(
      row.field.cardId,
      row.field.id,
      invalid: false,
    );
  }

  @override
  void dispose() {
    _clearMark(widget);
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
