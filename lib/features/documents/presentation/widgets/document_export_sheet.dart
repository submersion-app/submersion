import 'package:flutter/material.dart';

import 'package:submersion/core/services/export/zip/zip_crypto_writer.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks for the password of a documents export (#3397), showing how much
/// will be exported and what the protection is worth. Returns the password,
/// or null when dismissed. The password is held only by this sheet's fields.
Future<String?> showDocumentExportSheet(
  BuildContext context, {
  required int documentCount,
  required int fileCount,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      DocumentExportSheet(documentCount: documentCount, fileCount: fileCount),
);

class DocumentExportSheet extends StatefulWidget {
  final int documentCount;
  final int fileCount;

  const DocumentExportSheet({
    super.key,
    required this.documentCount,
    required this.fileCount,
  });

  @override
  State<DocumentExportSheet> createState() => _DocumentExportSheetState();
}

class _DocumentExportSheetState extends State<DocumentExportSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscured = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _passwordError(String value) {
    final l10n = context.l10n;
    if (!ZipCryptoWriter.isAsciiPassword(value)) {
      return l10n.documents_export_passwordCharacters;
    }
    if (value.length < ZipCryptoWriter.minPasswordLength) {
      return l10n.documents_export_passwordTooShort;
    }
    return null;
  }

  String? _confirmError(String value) => value == _password.text
      ? null
      : context.l10n.documents_export_passwordMismatch;

  void _submit() {
    if (_valid) Navigator.of(context).pop(_password.text);
  }

  bool get _valid =>
      ZipCryptoWriter.isValidPassword(_password.text) &&
      _confirm.text == _password.text;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final toggle = IconButton(
      tooltip: _obscured
          ? l10n.documents_export_showPassword
          : l10n.documents_export_hidePassword,
      icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
      onPressed: () => setState(() => _obscured = !_obscured),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        // Each field validates once it has been typed in, so the confirm
        // field stays quiet until the user reaches it.
        child: Form(
          onChanged: () => setState(() {}),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.documents_export_title,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.documents_export_summary(
                  widget.documentCount,
                  widget.fileCount,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                obscureText: _obscured,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: l10n.documents_export_password,
                  suffixIcon: toggle,
                ),
                validator: (v) => _passwordError(v ?? ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                obscureText: _obscured,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.documents_export_confirmPassword,
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => _confirmError(v ?? ''),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.documents_export_note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _valid ? _submit : null,
                child: Text(l10n.documents_export_start),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
