import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// A name-entry dialog shared by checklist creation and rename (issue
/// #3356): same title field, same validation, same actions, just a
/// different dialog title and initial value.
///
/// Owns its [TextEditingController] through its own State so disposal
/// happens when the framework actually removes this widget from the tree
/// (after the dialog's exit transition finishes), not right after
/// `showDialog` returns -- disposing eagerly there races the
/// still-animating `TextFormField` and throws "A TextEditingController was
/// used after being disposed."
class ChecklistNameDialog extends StatefulWidget {
  final String title;
  final String initialName;

  const ChecklistNameDialog({
    super.key,
    required this.title,
    this.initialName = '',
  });

  @override
  State<ChecklistNameDialog> createState() => _ChecklistNameDialogState();
}

class _ChecklistNameDialogState extends State<ChecklistNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.checklists_nameLabel),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? l10n.checklists_nameRequired
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
