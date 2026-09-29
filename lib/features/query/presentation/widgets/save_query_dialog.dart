import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The name prompt of spec Unit 7's "Save" (and the Manage page's rename).
/// Returns the trimmed name, or null when dismissed.
Future<String?> showSaveQueryDialog(
  BuildContext context, {
  String? initialName,
}) => showDialog<String>(
  context: context,
  builder: (_) => _SaveQueryDialog(initialName: initialName),
);

/// Owns its text controller, so the controller outlives the dialog's exit
/// animation and is disposed with the dialog itself.
class _SaveQueryDialog extends StatefulWidget {
  const _SaveQueryDialog({this.initialName});

  final String? initialName;

  @override
  State<_SaveQueryDialog> createState() => _SaveQueryDialogState();
}

class _SaveQueryDialogState extends State<_SaveQueryDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.query_saveDialog_title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.query_saveDialog_nameLabel,
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => value == null || value.trim().isEmpty
              ? l10n.query_saveDialog_nameValidation
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.common_action_save)),
      ],
    );
  }
}
