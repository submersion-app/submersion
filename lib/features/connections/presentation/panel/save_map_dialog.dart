import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks for a map name. Returns the trimmed name, or null when cancelled or
/// left empty.
Future<String?> showSaveMapDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) =>
        _SaveMapDialog(title: title, initialName: initialName),
  );
  final trimmed = name?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Owns its text controller so the controller outlives the closing
/// animation, which still rebuilds the field after the dialog pops.
class _SaveMapDialog extends StatefulWidget {
  const _SaveMapDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_SaveMapDialog> createState() => _SaveMapDialogState();
}

class _SaveMapDialogState extends State<_SaveMapDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

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
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.connections_savedMap_nameLabel,
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
