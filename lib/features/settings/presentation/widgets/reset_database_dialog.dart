import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Confirmation dialog for database reset with type-to-confirm safety gate.
///
/// The user must type "Delete" (case-sensitive) before the destructive
/// Reset button becomes enabled. Mirrors the pattern from
/// [RestoreConfirmationDialog] but adds the text confirmation step.
class ResetDatabaseDialog extends StatefulWidget {
  const ResetDatabaseDialog({super.key});

  /// Shows the dialog and returns true if the user confirms the reset.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ResetDatabaseDialog(),
    );
    return result ?? false;
  }

  @override
  State<ResetDatabaseDialog> createState() => _ResetDatabaseDialogState();
}

class _ResetDatabaseDialogState extends State<ResetDatabaseDialog> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;

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
    final confirmed = _controller.text.trim() == 'Delete';
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
          Expanded(
            child: Text(context.l10n.settings_storage_resetDialog_title),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.settings_storage_resetDialog_body,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: context.l10n.settings_storage_resetDialog_confirmHint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _isConfirmed
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(context.l10n.settings_storage_resetDialog_confirmButton),
        ),
      ],
    );
  }
}
