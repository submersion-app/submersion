import 'package:flutter/material.dart';

import 'package:submersion/features/media/data/synology/synology_album_source.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// [error], a subscription's recorded poll error, in the diver's language
/// where it is one the app itself wrote for a shared album's password; any
/// other error comes from the source and is shown as it was recorded.
String localizedPollError(AppLocalizations l10n, String error) =>
    switch (error) {
      kSynologyPasswordMissingMessage => l10n.media_sharePassword_needed,
      kSynologyPasswordRejectedMessage => l10n.media_sharePassword_rejected,
      _ => error,
    };

/// Asks for a Synology Photos share's password. Returns the password, or
/// null when the user cancels. [rejected] says the last one was refused.
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
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.media_sharePassword_title),
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
          Text(
            widget.rejected
                ? l10n.media_sharePassword_rejected
                : l10n.media_sharePassword_needed,
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
            decoration: InputDecoration(
              labelText: l10n.media_sharePassword_field,
              border: const OutlineInputBorder(),
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
          child: Text(l10n.media_sharePassword_save),
        ),
      ],
    );
  }
}
