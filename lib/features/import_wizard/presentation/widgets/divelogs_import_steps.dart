import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_import_adapter.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sign-in step for the divelogs.de import wizard.
///
/// Tries the cached session first; a token the server still accepts signs
/// straight in. Otherwise shows a username and password form. The password
/// lives only in the form and in the [DivelogsAuth] for this wizard run.
class DivelogsSignInStep extends ConsumerStatefulWidget {
  const DivelogsSignInStep({super.key, required this.onSignedIn});

  /// Receives the signed-in client, or null after signing out.
  final ValueChanged<DivelogsApiClient?> onSignedIn;

  @override
  ConsumerState<DivelogsSignInStep> createState() => _DivelogsSignInStepState();
}

class _DivelogsSignInStepState extends ConsumerState<DivelogsSignInStep> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  DivelogsAuth? _auth;
  bool _checkingCachedSession = true;
  bool _signedIn = false;
  bool _signingIn = false;
  bool _obscurePassword = true;
  String? _signedInUsername;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryCachedSession());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  DivelogsAuth _newAuth() => DivelogsAuth(
    httpClient: ref.read(divelogsHttpClientProvider),
    store: ref.read(divelogsSessionStoreProvider),
  );

  DivelogsApiClient _clientFor(DivelogsAuth auth) => DivelogsApiClient(
    getBearerToken: auth.getToken,
    onTokenRejected: auth.invalidateToken,
    httpClient: ref.read(divelogsHttpClientProvider),
  );

  Future<void> _tryCachedSession() async {
    final auth = _newAuth();
    final restored = await auth.restore();
    if (!mounted) return;
    if (!restored) {
      setState(() => _checkingCachedSession = false);
      return;
    }
    final client = _clientFor(auth);
    try {
      await client.getUser();
      if (!mounted) return;
      _auth = auth;
      _markSignedIn(client, auth.username!);
    } on DivelogsSessionExpiredException {
      // The cached token was rejected and auth cleared it: sign in afresh.
      if (!mounted) return;
      setState(() {
        _checkingCachedSession = false;
        _usernameController.text = auth.username ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingCachedSession = false;
        _usernameController.text = auth.username ?? '';
        _errorText = context.l10n.divelogsImport_signIn_unreachable;
      });
    }
  }

  void _markSignedIn(DivelogsApiClient client, String username) {
    widget.onSignedIn(client);
    setState(() {
      _checkingCachedSession = false;
      _signingIn = false;
      _signedIn = true;
      _signedInUsername = username;
      _errorText = null;
    });
    ref.read(divelogsSignedInProvider.notifier).state = true;
  }

  Future<void> _submit() async {
    if (_signingIn) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _signingIn = true;
      _errorText = null;
    });
    final auth = _newAuth();
    final username = _usernameController.text.trim();
    try {
      await auth.signIn(username, _passwordController.text);
      if (!mounted) return;
      _auth = auth;
      _passwordController.clear();
      _markSignedIn(_clientFor(auth), username);
    } on DivelogsAuthException catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      setState(() {
        _signingIn = false;
        _errorText = switch (e.reason) {
          DivelogsAuthFailure.badCredentials =>
            l10n.divelogsImport_signIn_badCredentials,
          DivelogsAuthFailure.unreachable =>
            l10n.divelogsImport_signIn_unreachable,
          DivelogsAuthFailure.unexpectedResponse =>
            l10n.divelogsImport_signIn_unexpected,
        };
      });
    }
  }

  Future<void> _signOut() async {
    final auth = _auth ?? _newAuth();
    await auth.signOut();
    _auth = null;
    widget.onSignedIn(null);
    ref.read(divelogsSignedInProvider.notifier).state = false;
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _signedInUsername = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (_checkingCachedSession) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_signedIn) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.divelogsImport_signIn_signedInAs(_signedInUsername ?? ''),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _signOut,
                child: Text(l10n.divelogsImport_signIn_signOut),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.divelogsImport_signIn_title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.divelogsImport_signIn_description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _usernameController,
              enabled: !_signingIn,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(
                labelText: l10n.divelogsImport_signIn_usernameLabel,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.divelogsImport_signIn_usernameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              enabled: !_signingIn,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: l10n.divelogsImport_signIn_passwordLabel,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: _signingIn
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                ),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? l10n.divelogsImport_signIn_passwordRequired
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _signingIn ? null : _submit,
              icon: _signingIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(
                _signingIn
                    ? l10n.divelogsImport_signIn_signingIn
                    : l10n.divelogsImport_signIn_button,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DivelogsFetchStep extends StatelessWidget {
  const DivelogsFetchStep({
    super.key,
    required this.client,
    required this.onPhotosListed,
  });

  final DivelogsApiClient? client;
  final ValueChanged<Map<String, List<RemotePhoto>>> onPhotosListed;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
