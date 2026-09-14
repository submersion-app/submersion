import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks for a person's name; [initial] empty means adding a new one.
/// Returns null when cancelled.
Future<String?> showLegacyNameDialog(
  BuildContext context, {
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _LegacyNameDialog(initial: initial),
);

class _LegacyNameDialog extends StatefulWidget {
  const _LegacyNameDialog({required this.initial});

  final String initial;

  @override
  State<_LegacyNameDialog> createState() => _LegacyNameDialogState();
}

class _LegacyNameDialogState extends State<_LegacyNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.initial.isEmpty
            ? l10n.buddies_linkText_addName
            : l10n.buddies_linkText_editName,
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l10n.buddies_linkText_nameLabel),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
