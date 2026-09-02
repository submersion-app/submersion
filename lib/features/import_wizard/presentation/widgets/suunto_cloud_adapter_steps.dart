import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_api_exception.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_client.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_session_store.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_sml_normalizer.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_cloud_adapter.dart';
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
/// corrupt file is handled elsewhere in the import pipeline.
class SuuntoCloudFetchStep extends ConsumerStatefulWidget {
  const SuuntoCloudFetchStep({
    super.key,
    required this.client,
    required this.onDivesFetched,
  });

  final SuuntoCloudClient? client;
  final void Function(List<SuuntoParsedDive> dives) onDivesFetched;

  @override
  ConsumerState<SuuntoCloudFetchStep> createState() =>
      _SuuntoCloudFetchStepState();
}

class _SuuntoCloudFetchStepState extends ConsumerState<SuuntoCloudFetchStep> {
  bool _isFetching = true;
  bool _isLoadingMore = false;
  bool _hasFetched = false;
  bool _hasMorePages = true;
  int _failedCount = 0;
  String? _error;
  String? _loadMoreError;
  String? _progressText;

  final List<SuuntoParsedDive> _parsedDives = [];

  /// Cursor for the next unfetched listing page.
  ///
  /// Only advanced once a page's listing call has actually returned, so a
  /// page that failed is re-requested by the next Load More rather than
  /// skipped.
  int _nextPageOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchFirstPage());
  }

  /// Clears any dives a previous attempt loaded, WITHOUT flipping
  /// [suuntoCloudDivesFetchedProvider].
  ///
  /// That provider is this step's `canAdvance`. Only the very first page's
  /// failure reaches this: once any page has succeeded, [_loadMore] reports
  /// its own errors separately rather than discarding already-usable dives.
  /// Leaving the provider false here keeps the error on screen with a Try
  /// Again button; Back and the wizard's close button both stay available,
  /// so this is not a dead end.
  void _discardDives() {
    widget.onDivesFetched(const []);
  }

  Future<void> _fetchFirstPage() async {
    final client = widget.client;
    if (client == null) {
      setState(() {
        _isFetching = false;
        _error = context.l10n.suuntoCloud_fetch_failedTitle;
      });
      _discardDives();
      return;
    }

    setState(() {
      _isFetching = true;
      _error = null;
      _parsedDives.clear();
      _failedCount = 0;
      _hasMorePages = true;
      _nextPageOffset = 0;
      // A retry starts the whole fetch over, so no paging error or spinner
      // from the previous attempt may survive into it.
      _loadMoreError = null;
      _isLoadingMore = false;
      _progressText = context.l10n.suuntoCloud_fetch_listing;
    });

    try {
      final page = await client.fetchDivePage();
      if (!mounted) return;
      _nextPageOffset = page.nextOffset;
      _hasMorePages = page.hasMore;

      if (page.dives.isNotEmpty) {
        await _downloadPage(client, page.dives);
        if (!mounted) return;
      }

      widget.onDivesFetched(List.unmodifiable(_parsedDives));
      setState(() {
        _isFetching = false;
        _hasFetched = true;
      });
      ref.read(suuntoCloudDivesFetchedProvider.notifier).state = true;
    } on SuuntoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetching = false;
        _error = e.displayMessage;
      });
      _discardDives();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetching = false;
        _error = '$e';
      });
      _discardDives();
    }
  }

  /// Fetches and downloads the next page of dives, on top of what an earlier
  /// call to [_fetchFirstPage] or [_loadMore] already made available.
  ///
  /// Reached only once the diver has already been shown at least one usable
  /// page, so a failure here must not wipe out those results the way a
  /// first-page failure does -- it's reported next to the Load More button
  /// instead, leaving everything fetched so far intact.
  Future<void> _loadMore() async {
    final client = widget.client;
    if (client == null || _isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await client.fetchDivePage(offset: _nextPageOffset);
      if (!mounted) return;
      _nextPageOffset = page.nextOffset;
      _hasMorePages = page.hasMore;

      if (page.dives.isNotEmpty) {
        await _downloadPage(client, page.dives);
        if (!mounted) return;
      }

      widget.onDivesFetched(List.unmodifiable(_parsedDives));
      setState(() => _isLoadingMore = false);
    } on SuuntoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = e.displayMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = '$e';
      });
    }
  }

  /// Downloads and converts every dive in [page], appending successes to
  /// [_parsedDives]. A single dive's fetch/normalize/parse failure is
  /// skipped rather than aborting the page, matching how a single corrupt
  /// file is handled elsewhere in the import pipeline.
  Future<void> _downloadPage(
    SuuntoCloudClient client,
    List<SuuntoWorkoutSummary> page,
  ) async {
    for (var i = 0; i < page.length; i++) {
      if (!mounted) return;
      setState(() {
        _progressText = context.l10n.suuntoCloud_fetch_fetchingDiveOf(
          i + 1,
          page.length,
        );
      });

      try {
        final bytes = await client.fetchSmlJson(page[i].key);
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final export = SuuntoSmlNormalizer.parse(json);
        final parsed = SuuntoDiveParser.parse(
          header: export.header,
          samples: export.samples,
        );
        _parsedDives.add(parsed);
      } catch (_) {
        _failedCount++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (_isFetching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _progressText ?? l10n.suuntoCloud_fetch_listing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.suuntoCloud_fetch_failedTitle,
                style: theme.textTheme.titleLarge,
              ),
              // The no-client branch has no detail beyond the headline; it
              // sets _error to the headline itself, so guard against
              // printing the same sentence twice.
              if (_error != l10n.suuntoCloud_fetch_failedTitle) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _fetchFirstPage,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.suuntoCloud_fetch_retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasFetched) {
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
                l10n.suuntoCloud_fetch_foundDives(_parsedDives.length),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (_failedCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.suuntoCloud_fetch_someFailed(_failedCount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_hasMorePages) ...[
                const SizedBox(height: 24),
                if (_isLoadingMore) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _progressText ?? l10n.suuntoCloud_fetch_listing,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.expand_more),
                    label: Text(l10n.suuntoCloud_fetch_loadMore),
                  ),
                if (_loadMoreError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _loadMoreError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
