import 'package:flutter/material.dart';

/// Asks for a Synology Photos share's password. Returns the password, or
/// null when the user cancels. [rejected] says the last one was refused.
///
/// Strings follow the media panels' hard-coded English until the feature
/// is localised.
Future<String?> showSynologyPasswordDialog(
  BuildContext context, {
  required String shareLabel,
  bool rejected = false,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _SynologyPasswordDialog(shareLabel: shareLabel, rejected: rejected),
);

class _SynologyPasswordDialog extends StatefulWidget {
  const _SynologyPasswordDialog({
    required this.shareLabel,
    required this.rejected,
  });

  final String shareLabel;
  final bool rejected;

  @override
  State<_SynologyPasswordDialog> createState() =>
      _SynologyPasswordDialogState();
}

class _SynologyPasswordDialogState extends State<_SynologyPasswordDialog> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _password.text;
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      // TODO(media): l10n
      title: const Text('Share password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.shareLabel,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // TODO(media): l10n
          Text(
            widget.rejected
                ? 'The share did not accept the password. Enter it again.'
                : 'This Synology Photos share needs its password.',
            key: const Key('synologyPasswordDialogReason'),
            style: widget.rejected
                ? TextStyle(color: theme.colorScheme.error)
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('synologyPasswordDialogField'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            // TODO(media): l10n
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('synologyPasswordDialogSave'),
          onPressed: _submit,
          // TODO(media): l10n
          child: const Text('Save and fetch'),
        ),
      ],
    );
  }
}
