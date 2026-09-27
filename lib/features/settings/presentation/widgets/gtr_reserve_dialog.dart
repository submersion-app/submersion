import 'package:flutter/material.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Edits the reserve pressure the calculated GTR counts down to.
///
/// Works in the diver's display unit: [initialValue] arrives already
/// converted and the value popped back is in the same unit, so the caller
/// converts to bar for storage. Pops null on cancel. Unreadable input keeps
/// the dialog open with the field's error, rather than closing with nothing
/// saved and nothing said (#1900).
class GtrReserveDialog extends StatefulWidget {
  final double initialValue;
  final String unitSymbol;

  const GtrReserveDialog({
    super.key,
    required this.initialValue,
    required this.unitSymbol,
  });

  @override
  State<GtrReserveDialog> createState() => _GtrReserveDialogState();
}

class _GtrReserveDialogState extends State<GtrReserveDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: formatDecimalForInput(widget.initialValue),
  );
  final _formKey = GlobalKey<FormState>();

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(switch (readNumber(_controller.text)) {
      NumberValue(:final value) => value,
      // Blank closes without a change, as before; the caller ignores null.
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
      title: Text(context.l10n.settings_decompression_gtrReserve),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: numberInputFormatters(),
          validator: numberValidator(context),
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
