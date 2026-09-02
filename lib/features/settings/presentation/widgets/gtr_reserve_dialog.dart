import 'package:flutter/material.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edits the reserve pressure the calculated GTR counts down to.
///
/// Works in the diver's display unit: [initialValue] arrives already
/// converted and the value popped back is in the same unit, so the caller
/// converts to bar for storage. Pops null on cancel or unreadable input.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.settings_decompression_gtrReserve),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(suffixText: widget.unitSymbol),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.settings_decompression_dialog_cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(parseUserDecimal(_controller.text)),
          child: Text(context.l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }
}
