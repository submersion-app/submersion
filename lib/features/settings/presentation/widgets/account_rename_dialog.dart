import 'package:flutter/material.dart';

import 'package:submersion/core/services/accounts/account_display_name.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/l10n/l10n_extension.dart';

/// Longest nickname the field accepts: a short name, not a description.
const int accountNicknameMaxLength = 40;

/// Asks for the short name [account] is shown under (issue #3522), starting
/// from its nickname. Returns the text to save, empty to go back to the
/// default name, or null when the diver cancels.
Future<String?> showAccountRenameDialog(
  BuildContext context,
  domain.ConnectedAccount account,
) => showDialog<String>(
  context: context,
  builder: (_) => _AccountRenameDialog(account: account),
);

class _AccountRenameDialog extends StatefulWidget {
  const _AccountRenameDialog({required this.account});

  final domain.ConnectedAccount account;

  @override
  State<_AccountRenameDialog> createState() => _AccountRenameDialogState();
}

class _AccountRenameDialogState extends State<_AccountRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.account.nickname ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settings_connectedAccounts_renameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: accountNicknameMaxLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: l10n.settings_connectedAccounts_renameField,
          helperText: l10n.settings_connectedAccounts_renameDefault(
            shortStorageLabel(widget.account.label),
          ),
          helperMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(onPressed: _save, child: Text(material.saveButtonLabel)),
      ],
    );
  }
}
