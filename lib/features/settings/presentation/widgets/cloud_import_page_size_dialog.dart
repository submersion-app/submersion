import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/features/import_wizard/domain/cloud_import_paging.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edits how many of the latest cloud dives to fetch per page.
///
/// Pops the entered integer on save, or null on cancel / unreadable input.
class CloudImportPageSizeDialog extends StatefulWidget {
  const CloudImportPageSizeDialog({super.key, required this.initialValue});

  final int initialValue;

  @override
  State<CloudImportPageSizeDialog> createState() =>
      _CloudImportPageSizeDialogState();
}

class _CloudImportPageSizeDialogState extends State<CloudImportPageSizeDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initialValue}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(CloudImportPaging.clamp(parsed));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settings_cloudImportPageSize_dialogTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.settings_decompression_dialog_cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }
}
