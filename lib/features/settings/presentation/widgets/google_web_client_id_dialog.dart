import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/google_web_client_id_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_web_client_id_store.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/browser_launch.dart';

/// The user guide's walkthrough of creating the client in Google Cloud.
final Uri kGoogleWebClientIdGuide = Uri.parse(
  'https://github.com/submersion-app/submersion/blob/main/docs/user/web-app.md#google-drive',
);

/// Asks a browser user for the Google client id of their own Google Cloud
/// project before the first Google sign-in (issue #4121). Checks the id's
/// shape, stores it with the other sign-in details and pops `true`.
///
/// [openUri] is injectable for widget tests; production uses [openInBrowser].
class GoogleWebClientIdDialog extends ConsumerStatefulWidget {
  const GoogleWebClientIdDialog({super.key, this.openUri});

  final Future<bool> Function(Uri uri)? openUri;

  @override
  ConsumerState<GoogleWebClientIdDialog> createState() =>
      _GoogleWebClientIdDialogState();
}

class _GoogleWebClientIdDialogState
    extends ConsumerState<GoogleWebClientIdDialog> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final clientId = GoogleWebClientIdStore.normalize(_controller.text);
    if (clientId == null) {
      setState(() => _errorText = l10n.web_googleClientId_invalid);
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await ref.read(googleWebClientIdStoreProvider).write(clientId);
    } catch (e) {
      // Browser storage can refuse a write; the dialog stays usable.
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = '$e';
        });
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.web_googleClientId_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.web_googleClientId_body),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: l10n.web_googleClientId_hint,
              errorText: _errorText,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _save(),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  (widget.openUri ?? openInBrowser)(kGoogleWebClientIdGuide),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.web_googleClientId_help),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
