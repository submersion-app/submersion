import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_import_adapter.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/photo_folder_step.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_import_service.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('DivelogsImportSteps');

/// A signed-in divelogs.de session: the auth that owns the token (and, for
/// a sign-in made in this wizard run, the password in memory) and the client
/// built on it. A client made without an auth (tests) has none.
typedef DivelogsSignedIn = ({DivelogsAuth? auth, DivelogsApiClient client});

/// Sign-in step for the divelogs.de import wizard.
///
/// Tries the cached session first; a token the server still accepts signs
/// straight in. Otherwise shows a username and password form. The password
/// lives only in the form and in the [DivelogsAuth] for this wizard run.
class DivelogsSignInStep extends ConsumerStatefulWidget {
  const DivelogsSignInStep({
    super.key,
    required this.onSignedIn,
    this.current,
    this.prefillUsername,
  });

  /// Receives the new session, or null after signing out.
  final ValueChanged<DivelogsSignedIn?> onSignedIn;

  /// The session the wizard already holds. Coming back to this step keeps
  /// it, with its in-memory password, instead of rebuilding one from the
  /// keychain that could no longer renew an expired token.
  final DivelogsSignedIn? current;

  /// The username of a session that expired, filled into the form.
  final String? prefillUsername;

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
    final current = widget.current;
    final username = current?.auth?.username;
    if (current != null && username != null) {
      _auth = current.auth;
      _checkingCachedSession = false;
      _signedIn = true;
      _signedInUsername = username;
      return;
    }
    _usernameController.text = widget.prefillUsername ?? '';
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
    final bool restored;
    try {
      restored = await auth.restore();
    } catch (e) {
      // An unreadable keychain only costs the cached session: offer the form.
      _log.warning('Could not read the divelogs.de session: ${e.runtimeType}');
      if (mounted) setState(() => _checkingCachedSession = false);
      return;
    }
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
      _markSignedIn(auth, client, auth.username!);
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

  void _markSignedIn(
    DivelogsAuth auth,
    DivelogsApiClient client,
    String username,
  ) {
    widget.onSignedIn((auth: auth, client: client));
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
      _markSignedIn(auth, _clientFor(auth), username);
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
    } catch (e) {
      // The keychain refused the session, or something else outside
      // divelogs.de failed; never leave the form stuck on its spinner.
      _log.warning('divelogs.de sign-in failed: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _errorText = context.l10n.common_error_tryAgain;
      });
    }
  }

  Future<void> _signOut() async {
    final auth = _auth ?? _newAuth();
    try {
      await auth.signOut();
    } catch (e) {
      // The keychain kept the session, so this is not a sign-out: stay
      // signed in and say so, rather than let the cached token sign the
      // same account back in next time.
      _log.warning('Could not clear the divelogs.de session: ${e.runtimeType}');
      if (!mounted) return;
      setState(() => _errorText = context.l10n.common_error_tryAgain);
      return;
    }
    _auth = null;
    widget.onSignedIn(null);
    ref.read(divelogsSignedInProvider.notifier).state = false;
    // A fetch made under the account just signed out of must not import.
    ref.read(divelogsFetchedProvider.notifier).state = false;
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
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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

/// Fetch step for the divelogs.de import wizard.
///
/// Fetches the whole logbook in one go (divelogs.de has no paging) and, when
/// asked and the Photos step can pick a folder on this platform, lists each
/// dive's photos. What was found, and any list that could not be fetched,
/// stays on screen until the diver moves on.
class DivelogsFetchStep extends ConsumerStatefulWidget {
  const DivelogsFetchStep({
    super.key,
    required this.client,
    required this.onPhotosListed,
    this.onSessionExpired,
  });

  final DivelogsApiClient? client;
  final ValueChanged<Map<String, List<RemotePhoto>>> onPhotosListed;

  /// Called when divelogs.de no longer accepts the session, so the wizard
  /// can send the diver back to sign in.
  final VoidCallback? onSessionExpired;

  @override
  ConsumerState<DivelogsFetchStep> createState() => _DivelogsFetchStepState();
}

enum _FetchPhase { idle, fetching, done, empty, failed, expired }

class _DivelogsFetchStepState extends ConsumerState<DivelogsFetchStep> {
  _FetchPhase _phase = _FetchPhase.idle;
  DivelogsFetchResult? _result;
  (int, int)? _photoProgress;

  Future<void> _fetch() async {
    final client = widget.client;
    if (client == null) return;
    final includePhotos =
        PhotoFolderStep.canPickFolder &&
        ref.read(divelogsIncludePhotosProvider);
    // Until this fetch succeeds, nothing fetched earlier may be imported:
    // not the flag, not the payload, selections or photo decisions.
    ref.read(divelogsFetchedProvider.notifier).state = false;
    ref.read(universalImportNotifierProvider.notifier).reset();
    final generation = ref.read(divelogsSessionGenerationProvider);
    bool sessionChanged() =>
        !mounted || ref.read(divelogsSessionGenerationProvider) != generation;
    setState(() {
      _phase = _FetchPhase.fetching;
      _photoProgress = null;
    });
    try {
      final result = await DivelogsImportService(api: client).fetchLogbook(
        includePhotos: includePhotos,
        onPhotoListingProgress: (current, total) {
          if (mounted) setState(() => _photoProgress = (current, total));
        },
      );
      // Signed out or switched accounts while the request was in flight.
      if (sessionChanged()) {
        _backToIdle();
        return;
      }
      if (result.payload.isEmpty) {
        setState(() => _phase = _FetchPhase.empty);
        return;
      }
      widget.onPhotosListed(result.photosBySourceUuid);
      await ref
          .read(universalImportNotifierProvider.notifier)
          .setExternalPayload(
            result.payload,
            remotePhotoCount: result.photoCount,
          );
      // A step disposed mid-install must not touch its ref; the fetched
      // flag it would set is what gates the import, and it stays false.
      if (!mounted) return;
      if (sessionChanged()) {
        // The session changed while the payload was being installed; the
        // change already reset the notifier, so drop what landed after it.
        ref.read(universalImportNotifierProvider.notifier).reset();
        _backToIdle();
        return;
      }
      setState(() {
        _result = result;
        _phase = _FetchPhase.done;
      });
      ref.read(divelogsFetchedProvider.notifier).state = true;
    } on DivelogsSessionExpiredException {
      _markExpired();
    } on DivelogsUnauthorizedException {
      // divelogs.de refused the session even after renewing it.
      _markExpired();
    } on DivelogsApiException {
      if (!mounted) return;
      setState(() => _phase = _FetchPhase.failed);
    } on DivelogsAuthException catch (e) {
      // Renewing the token mid-fetch failed. Refused credentials (the
      // password changed) end the session; anything else is worth a retry.
      if (e.reason == DivelogsAuthFailure.badCredentials) {
        _markExpired();
        return;
      }
      if (!mounted) return;
      setState(() => _phase = _FetchPhase.failed);
    } catch (e) {
      // Anything else (a keychain error while renewing, say) is offered a
      // retry rather than leaving the step on its spinner.
      _log.warning('divelogs.de fetch failed: ${e.runtimeType}');
      if (!mounted) return;
      setState(() => _phase = _FetchPhase.failed);
    }
  }

  /// Offers a fresh fetch after a result was dropped for a changed session.
  void _backToIdle() {
    if (mounted) setState(() => _phase = _FetchPhase.idle);
  }

  void _markExpired() {
    if (!mounted) return;
    ref.read(divelogsSignedInProvider.notifier).state = false;
    setState(() => _phase = _FetchPhase.expired);
    widget.onSessionExpired?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canListPhotos = PhotoFolderStep.canPickFolder;

    Widget fetchButton() => FilledButton.icon(
      onPressed: widget.client == null ? null : _fetch,
      icon: const Icon(Icons.cloud_download),
      label: Text(l10n.divelogsImport_fetch_button),
    );

    Widget problem(String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );

    final children = <Widget>[];
    switch (_phase) {
      case _FetchPhase.idle:
        if (canListPhotos) {
          children.add(
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.divelogsImport_fetch_includePhotos),
              subtitle: Text(l10n.divelogsImport_fetch_includePhotosHint),
              value: ref.watch(divelogsIncludePhotosProvider),
              onChanged: (value) =>
                  ref.read(divelogsIncludePhotosProvider.notifier).state =
                      value,
            ),
          );
          children.add(const SizedBox(height: 16));
        }
        children.add(fetchButton());
      case _FetchPhase.fetching:
        final progress = _photoProgress;
        children.add(
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  progress == null
                      ? l10n.divelogsImport_fetch_fetching
                      : l10n.divelogsImport_fetch_listingPhotos(
                          progress.$1,
                          progress.$2,
                        ),
                ),
              ),
            ],
          ),
        );
      case _FetchPhase.done:
        final result = _result!;
        children.add(
          Text(
            l10n.divelogsImport_fetch_foundDives(result.diveCount),
            style: theme.textTheme.titleMedium,
          ),
        );
        if (result.photoCount > 0 || result.photoListingFailures > 0) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.divelogsImport_fetch_foundPhotos(result.photoCount),
              ),
            ),
          );
        }
        if (result.skippedDives > 0) {
          children.add(
            problem(
              l10n.divelogsImport_fetch_skippedDives(result.skippedDives),
            ),
          );
        }
        if (result.gearUnavailable) {
          children.add(problem(l10n.divelogsImport_fetch_gearUnavailable));
        }
        if (result.certificationsUnavailable) {
          children.add(
            problem(l10n.divelogsImport_fetch_certificationsUnavailable),
          );
        }
        if (result.photoListingFailures > 0) {
          children.add(
            problem(
              l10n.divelogsImport_fetch_photoListingsFailed(
                result.photoListingFailures,
              ),
            ),
          );
        }
      case _FetchPhase.empty:
        children.add(Text(l10n.divelogsImport_fetch_empty));
        children.add(const SizedBox(height: 16));
        children.add(fetchButton());
      case _FetchPhase.failed:
        children.add(
          Text(
            l10n.divelogsImport_fetch_failedTitle,
            style: theme.textTheme.titleMedium,
          ),
        );
        children.add(const SizedBox(height: 16));
        children.add(
          FilledButton(
            onPressed: _fetch,
            child: Text(l10n.divelogsImport_fetch_retry),
          ),
        );
      case _FetchPhase.expired:
        children.add(Text(l10n.divelogsImport_fetch_sessionExpired));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
