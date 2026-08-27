import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Confirmation dialog for diver deletion with type-to-confirm safety gate.
///
/// The user must type "Delete {name}" (case-sensitive) before the destructive
/// Delete button becomes enabled.
class DeleteDiverDialog extends StatefulWidget {
  const DeleteDiverDialog({super.key, required this.diverName});

  final String diverName;

  /// Shows the dialog and returns true if the user confirms the deletion.
  static Future<bool> show(
    BuildContext context, {
    required String diverName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteDiverDialog(diverName: diverName),
    );
    return result ?? false;
  }

  @override
  State<DeleteDiverDialog> createState() => _DeleteDiverDialogState();
}

class _DeleteDiverDialogState extends State<DeleteDiverDialog> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;
  late String _confirmationText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _confirmationText = context.l10n.divers_detail_deleteDialogConfirmText(
      widget.diverName,
    );
    // Re-evaluate in case locale changed while user had typed text.
    final confirmed = _controller.text.trim() == _confirmationText;
    if (confirmed != _isConfirmed) {
      setState(() => _isConfirmed = confirmed);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final confirmed = _controller.text.trim() == _confirmationText;
    if (confirmed != _isConfirmed) {
      setState(() => _isConfirmed = confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(context.l10n.divers_detail_deleteDialogTitle)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.divers_detail_deleteDialogContent(widget.diverName),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: context.l10n.divers_detail_deleteDialogConfirmHint(
                widget.diverName,
              ),
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.divers_detail_cancelButton),
        ),
        FilledButton(
          onPressed: _isConfirmed
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(context.l10n.divers_detail_deleteButton),
        ),
      ],
    );
  }
}
