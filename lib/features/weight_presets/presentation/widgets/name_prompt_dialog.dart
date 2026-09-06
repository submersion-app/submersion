import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// A single-field "name this" dialog that owns its [TextEditingController], so
/// callers never have to juggle its lifetime. Pops the trimmed text, or null.
class NamePromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  final String confirmLabel;

  const NamePromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
    this.initialValue = '',
  });

  /// Shows the dialog and returns the trimmed non-empty name, or null.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    required String confirmLabel,
    String initialValue = '',
  }) => showDialog<String>(
    context: context,
    builder: (_) => NamePromptDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
    ),
  );

  @override
  State<NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<NamePromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_cancel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
