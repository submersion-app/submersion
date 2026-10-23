import 'package:flutter/material.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Edits one of the planner Setup-accordion global defaults (issue #3552):
/// Rates, Gas, Contingency and DPV Team values, each a plain number in the
/// diver's display unit, with no per-plan override concept - this IS the
/// global default, so there is nothing to clear back to.
///
/// Works in the diver's display unit, same contract as [GtrReserveDialog]:
/// [initialValue] arrives already converted and the value popped back is in
/// the same unit, so the caller converts to the stored unit. Pops null on
/// cancel or blank/unreadable input, which the caller ignores.
class PlannerDefaultNumberDialog extends StatefulWidget {
  final String title;
  final double initialValue;
  final String unitSymbol;
  final bool integer;

  const PlannerDefaultNumberDialog({
    super.key,
    required this.title,
    required this.initialValue,
    required this.unitSymbol,
    this.integer = false,
  });

  @override
  State<PlannerDefaultNumberDialog> createState() =>
      _PlannerDefaultNumberDialogState();
}

class _PlannerDefaultNumberDialogState
    extends State<PlannerDefaultNumberDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.integer
        ? formatDecimalForInput(widget.initialValue.roundToDouble())
        : formatDecimalForInput(widget.initialValue),
  );
  final _formKey = GlobalKey<FormState>();

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(switch (readNumber(
      _controller.text,
      integer: widget.integer,
    )) {
      NumberValue(:final value) => value,
      NumberBlank() || NumberInvalid() => null,
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(
            decimal: !widget.integer,
          ),
          inputFormatters: numberInputFormatters(),
          validator: numberValidator(context, integer: widget.integer),
          decoration: InputDecoration(suffixText: widget.unitSymbol),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.settings_decompression_dialog_cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }
}

/// One planner default in a Settings card (issue #3552): [label], the
/// current value as [valueText], and a tap that edits it in a
/// [PlannerDefaultNumberDialog]. [initialValue] and the value handed to
/// [onSaved] are in the diver's display unit. A blank, unreadable or
/// non-finite entry, or one [accept] rejects, is dropped.
class PlannerDefaultTile extends StatelessWidget {
  final String label;
  final String valueText;
  final double initialValue;
  final String unitSymbol;
  final bool integer;
  final bool Function(double value) accept;
  final ValueChanged<double> onSaved;

  const PlannerDefaultTile({
    super.key,
    required this.label,
    required this.valueText,
    required this.initialValue,
    required this.unitSymbol,
    required this.onSaved,
    this.integer = false,
    this.accept = positive,
  });

  /// The default [accept]: a value above zero.
  static bool positive(double value) => value > 0;

  /// For a default where 0 ("none") is a valid choice.
  static bool nonNegative(double value) => value >= 0;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(valueText, style: Theme.of(context).textTheme.titleMedium),
      onTap: () async {
        final entered = await showDialog<double>(
          context: context,
          builder: (_) => PlannerDefaultNumberDialog(
            title: label,
            initialValue: initialValue,
            unitSymbol: unitSymbol,
            integer: integer,
          ),
        );
        if (entered == null || !entered.isFinite || !accept(entered)) return;
        onSaved(entered);
      },
    );
  }
}
