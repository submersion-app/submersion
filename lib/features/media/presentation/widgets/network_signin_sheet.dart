// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 15. The plan is intentionally light here ("hostname read-only,
// auth type segmented control, conditional fields, Save button calls
// `urlTabNotifierProvider.notifier.saveCredentials(...)`") so the test
// assertions in `test/features/media/presentation/widgets/url_tab_test.dart`
// drive the contract: a `NetworkSignInSheet` widget that exposes
// "Username", "Password" `TextField`s for basic auth and a "Save"
// `FilledButton` that forwards to `saveCredentials`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

/// Two-mode segmented control for the auth type. Maps to the persisted
/// `authType` strings ("basic" / "bearer") expected by
/// [NetworkCredentialsService.save].
enum NetworkAuthType { basic, bearer }

extension on NetworkAuthType {
  String get wireValue => switch (this) {
    NetworkAuthType.basic => 'basic',
    NetworkAuthType.bearer => 'bearer',
  };
}

/// Modal bottom sheet shown when an unauthenticated host requires the
/// user to provide credentials before the URL tab can fetch its assets.
///
/// Hostname is read-only (set by the caller from the URL that triggered
/// the prompt). The sheet collects username + password (basic) or token
/// (bearer) and forwards them to
/// [UrlTabNotifier.saveCredentials], which in turn updates the secure
/// storage entry through [NetworkCredentialsService.save].
class NetworkSignInSheet extends ConsumerStatefulWidget {
  const NetworkSignInSheet({super.key, required this.hostname});

  final String hostname;

  @override
  ConsumerState<NetworkSignInSheet> createState() => _NetworkSignInSheetState();
}

class _NetworkSignInSheetState extends ConsumerState<NetworkSignInSheet> {
  NetworkAuthType _authType = NetworkAuthType.basic;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _token = TextEditingController();
  final TextEditingController _displayName = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _token.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final notifier = ref.read(urlTabNotifierProvider.notifier);
    try {
      await notifier.saveCredentials(
        hostname: widget.hostname,
        authType: _authType.wireValue,
        username: _authType == NetworkAuthType.basic
            ? _username.text.trim()
            : null,
        password: _authType == NetworkAuthType.basic ? _password.text : null,
        token: _authType == NetworkAuthType.bearer ? _token.text.trim() : null,
        displayName: _displayName.text.trim().isEmpty
            ? null
            : _displayName.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TODO(media): l10n
          Text(
            'Sign in to ${widget.hostname}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          // TODO(media): l10n
          Text(
            'These credentials are stored in your platform keychain.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SegmentedButton<NetworkAuthType>(
            segments: const [
              // TODO(media): l10n
              ButtonSegment(value: NetworkAuthType.basic, label: Text('Basic')),
              // TODO(media): l10n
              ButtonSegment(
                value: NetworkAuthType.bearer,
                label: Text('Bearer'),
              ),
            ],
            selected: {_authType},
            onSelectionChanged: (selected) {
              setState(() => _authType = selected.first);
            },
          ),
          const SizedBox(height: 16),
          if (_authType == NetworkAuthType.basic) ...[
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                // TODO(media): l10n
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(
                // TODO(media): l10n
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              autofillHints: const [AutofillHints.password],
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
          ] else ...[
            TextField(
              controller: _token,
              decoration: const InputDecoration(
                // TODO(media): l10n
                labelText: 'Token',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(
              // TODO(media): l10n
              labelText: 'Display name (optional)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                // TODO(media): l10n
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                // TODO(media): l10n
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
