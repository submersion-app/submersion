import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_api_exception.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_client.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_session_store.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_sml_normalizer.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/cloud_import_fetch_step.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sign-in step for the Suunto cloud import wizard.
///
/// Tries a cached session first (via [SuuntoSessionStore]); only falls back
/// to an email/password form when there is no cached session or the server
/// no longer accepts it.
class SuuntoCloudSignInStep extends ConsumerStatefulWidget {
  const SuuntoCloudSignInStep({super.key, required this.onSignedIn});

  final ValueChanged<SuuntoCloudClient> onSignedIn;

  @override
  ConsumerState<SuuntoCloudSignInStep> createState() =>
      _SuuntoCloudSignInStepState();
}

class _SuuntoCloudSignInStepState extends ConsumerState<SuuntoCloudSignInStep> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _checkingCachedSession = true;
  bool _signedIn = false;
  bool _signingIn = false;
  bool _obscurePassword = true;
  String? _signedInEmail;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryCachedSession());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryCachedSession() async {
    final cached = await ref.read(suuntoSessionStoreProvider).load();
    if (!mounted) return;

    if (cached == null) {
      setState(() {
        _checkingCachedSession = false;
        _emailController.text = '';
      });
      return;
    }

    final client = ref.read(suuntoCloudClientFactoryProvider)()
      ..sessionKey = cached.sessionKey;
    bool valid;
    try {
      valid = await client.verifySession();
    } catch (_) {
      valid = false;
    }
    if (!mounted) return;

    if (valid) {
      _emailController.text = cached.email;
      _markSignedIn(client, cached.email);
      return;
    }

    setState(() {
      _checkingCachedSession = false;
      _emailController.text = cached.email;
    });
  }

  void _markSignedIn(SuuntoCloudClient client, String email) {
    widget.onSignedIn(client);
    setState(() {
      _checkingCachedSession = false;
      _signingIn = false;
      _signedIn = true;
      _signedInEmail = email;
    });
    ref.read(suuntoCloudSignedInProvider.notifier).state = true;
  }

  Future<void> _submit() async {
    if (_signingIn) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _signingIn = true;
      _errorText = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final client = ref.read(suuntoCloudClientFactoryProvider)();

    try {
      await client.login(email, password);
      await ref
          .read(suuntoSessionStoreProvider)
          .save(
            SuuntoSessionData(email: email, sessionKey: client.sessionKey!),
          );
      if (!mounted) return;
      _markSignedIn(client, email);
    } on SuuntoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _errorText = e.displayMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _errorText = '$e';
      });
    }
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
                l10n.suuntoCloud_signIn_signedInAs(_signedInEmail ?? ''),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
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
              l10n.suuntoCloud_signIn_title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.suuntoCloud_signIn_description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              enabled: !_signingIn,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: l10n.suuntoCloud_signIn_emailLabel,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.suuntoCloud_signIn_emailRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              enabled: !_signingIn,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: l10n.suuntoCloud_signIn_passwordLabel,
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
                  ? l10n.suuntoCloud_signIn_passwordRequired
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
                    ? l10n.suuntoCloud_signIn_signingIn
                    : l10n.suuntoCloud_signIn_button,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fetch step for the Suunto cloud import wizard.
///
/// Lists dive-activity workouts a page at a time, downloading and converting
/// each one in turn. A single dive's fetch/normalize/parse failure is
/// skipped rather than aborting the whole fetch, matching how a single
/// corrupt file is handled elsewhere in the import pipeline. Paging, Fetch
/// All, and the selection list live in [CloudImportFetchStep].
class SuuntoCloudFetchStep extends StatelessWidget {
  const SuuntoCloudFetchStep({
    super.key,
    required this.client,
    required this.onDivesFetched,
  });

  final SuuntoCloudClient? client;
  final void Function(List<SuuntoParsedDive> dives) onDivesFetched;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CloudImportFetchStep<SuuntoWorkoutSummary, SuuntoParsedDive>(
      hasClient: client != null,
      fetchPage: ({required int cursor, required int pageSize}) async {
        final page = await client!.fetchDivePage(
          offset: cursor,
          pageSize: pageSize,
        );
        return CloudImportListingPage(
          items: page.dives,
          nextCursor: page.nextOffset,
          hasMore: page.hasMore,
        );
      },
      downloadPage: (page, onProgress) async {
        final results = <SuuntoParsedDive?>[];
        for (var i = 0; i < page.length; i++) {
          onProgress(i + 1, page.length);
          try {
            final bytes = await client!.fetchSmlJson(page[i].key);
            final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
            final export = SuuntoSmlNormalizer.parse(json);
            results.add(
              SuuntoDiveParser.parse(
                header: export.header,
                samples: export.samples,
              ),
            );
          } catch (_) {
            results.add(null);
          }
        }
        return results;
      },
      diveOf: (parsed) => parsed.dive,
      onDivesFetched: onDivesFetched,
      divesFetchedProvider: suuntoCloudDivesFetchedProvider,
      strings: CloudImportFetchStrings.suunto(l10n),
      formatError: (error) =>
          error is SuuntoApiException ? error.displayMessage : '$error',
    );
  }
}
