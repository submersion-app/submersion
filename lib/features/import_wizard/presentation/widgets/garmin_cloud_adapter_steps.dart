import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/garmin_connect/garmin_api_exception.dart';
import 'package:submersion/core/services/garmin_connect/garmin_connect_client.dart';
import 'package:submersion/core/services/garmin_connect/garmin_dive_mapper.dart';
import 'package:submersion/core/services/garmin_connect/garmin_session_store.dart';
import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/import_wizard/data/adapters/garmin_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/cloud_import_fetch_step.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sign-in step for the Garmin Connect import wizard.
///
/// Tries a cached session first (via [GarminSessionStore]); only falls back
/// to an email/password form when there is no cached session or the server
/// no longer accepts it. A password sign-in may be interrupted by Garmin's
/// MFA challenge, in which case a verification-code sub-form replaces the
/// password form until the code is accepted.
class GarminCloudSignInStep extends ConsumerStatefulWidget {
  const GarminCloudSignInStep({super.key, required this.onSignedIn});

  final ValueChanged<GarminConnectClient> onSignedIn;

  @override
  ConsumerState<GarminCloudSignInStep> createState() =>
      _GarminCloudSignInStepState();
}

class _GarminCloudSignInStepState extends ConsumerState<GarminCloudSignInStep> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();

  bool _checkingCachedSession = true;
  bool _signedIn = false;
  bool _signingIn = false;
  bool _obscurePassword = true;
  bool _awaitingMfa = false;
  String? _mfaMethod;
  String? _signedInEmail;
  String? _errorText;

  GarminConnectClient? _pendingClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryCachedSession());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  Future<void> _tryCachedSession() async {
    final cached = await ref.read(garminSessionStoreProvider).load();
    if (!mounted) return;

    if (cached == null) {
      setState(() {
        _checkingCachedSession = false;
        _emailController.text = '';
      });
      return;
    }

    final client = ref.read(garminConnectClientFactoryProvider)();
    bool valid;
    try {
      await client.restoreSession(cached.token);
      valid = true;
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

  void _markSignedIn(GarminConnectClient client, String email) {
    widget.onSignedIn(client);
    setState(() {
      _checkingCachedSession = false;
      _signingIn = false;
      _awaitingMfa = false;
      _signedIn = true;
      _signedInEmail = email;
    });
    ref.read(garminCloudSignedInProvider.notifier).state = true;
  }

  Future<void> _saveSessionAndMarkSignedIn(
    GarminConnectClient client,
    String email,
  ) async {
    final token = client.oauth1Token;
    if (token != null) {
      await ref
          .read(garminSessionStoreProvider)
          .save(GarminSessionData(email: email, token: token));
    }
    if (!mounted) return;
    _markSignedIn(client, email);
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
    final client = ref.read(garminConnectClientFactoryProvider)();

    try {
      final result = await client.login(email, password);
      if (!mounted) return;

      if (result.mfaRequired) {
        setState(() {
          _signingIn = false;
          _awaitingMfa = true;
          _mfaMethod = result.mfaMethod;
          _pendingClient = client;
        });
        return;
      }

      await _saveSessionAndMarkSignedIn(client, email);
    } on GarminApiException catch (e) {
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

  Future<void> _submitMfaCode() async {
    if (_signingIn) return;
    final client = _pendingClient;
    if (client == null) return;

    final code = _mfaCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = context.l10n.garminConnect_mfa_codeRequired);
      return;
    }

    setState(() {
      _signingIn = true;
      _errorText = null;
    });

    try {
      await client.submitMfaCode(code, mfaMethod: _mfaMethod ?? 'email');
      if (!mounted) return;
      await _saveSessionAndMarkSignedIn(client, _emailController.text.trim());
    } on GarminApiException catch (e) {
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
                l10n.garminConnect_signIn_signedInAs(_signedInEmail ?? ''),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_awaitingMfa) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.garminConnect_mfa_title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.garminConnect_mfa_description(_mfaMethod ?? 'email'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _mfaCodeController,
              enabled: !_signingIn,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.garminConnect_mfa_codeLabel,
              ),
              onSubmitted: (_) => _submitMfaCode(),
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
              onPressed: _signingIn ? null : _submitMfaCode,
              icon: _signingIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(
                _signingIn
                    ? l10n.garminConnect_mfa_submitting
                    : l10n.garminConnect_mfa_button,
              ),
            ),
          ],
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
              l10n.garminConnect_signIn_title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.garminConnect_signIn_description,
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
                labelText: l10n.garminConnect_signIn_emailLabel,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.garminConnect_signIn_emailRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              enabled: !_signingIn,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: l10n.garminConnect_signIn_passwordLabel,
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
                  ? l10n.garminConnect_signIn_passwordRequired
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
                    ? l10n.garminConnect_signIn_signingIn
                    : l10n.garminConnect_signIn_button,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fetch step for the Garmin Connect import wizard.
///
/// Lists every diving/apnea activity, then downloads and parses each page's
/// FIT files in parallel. A single dive's fetch/parse failure is skipped
/// rather than aborting the whole fetch, matching how a single corrupt file
/// is handled elsewhere in the import pipeline. Paging, Fetch All, and the
/// selection list live in [CloudImportFetchStep].
class GarminCloudFetchStep extends StatelessWidget {
  const GarminCloudFetchStep({
    super.key,
    required this.client,
    required this.onDivesFetched,
  });

  final GarminConnectClient? client;
  final void Function(List<GarminParsedDive> dives) onDivesFetched;

  static const _fitParser = FitParserService();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CloudImportFetchStep<GarminActivitySummary, GarminParsedDive>(
      hasClient: client != null,
      fetchPage: ({required int cursor, required int pageSize}) async {
        final page = await client!.fetchDivePage(
          start: cursor,
          pageSize: pageSize,
        );
        return CloudImportListingPage(
          items: page.dives,
          nextCursor: page.nextStart,
          hasMore: page.hasMore,
        );
      },
      downloadPage: (page, onProgress) async {
        final results = List<GarminParsedDive?>.filled(page.length, null);
        var completed = 0;

        Future<void> downloadOne(int i) async {
          try {
            final activityId = page[i].activityId;
            final bytes = await client!.downloadActivityFit(activityId);
            final imported = await _fitParser.parseFitFile(bytes);
            if (imported != null) {
              results[i] = GarminDiveMapper.map(
                imported,
                activityId: activityId,
                fallbackLatitude: page[i].latitude,
                fallbackLongitude: page[i].longitude,
              );
            }
          } catch (_) {
            // Left null; counted as a failure by the shared fetch step.
          } finally {
            completed++;
            onProgress(completed, page.length);
          }
        }

        await Future.wait(List.generate(page.length, downloadOne));
        return results;
      },
      diveOf: (parsed) => parsed.dive,
      onDivesFetched: onDivesFetched,
      divesFetchedProvider: garminCloudDivesFetchedProvider,
      strings: CloudImportFetchStrings.garmin(l10n),
      formatError: (error) =>
          error is GarminApiException ? error.displayMessage : '$error',
    );
  }
}
