import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/garmin_connect/garmin_api_exception.dart';
import 'package:submersion/core/services/garmin_connect/garmin_connect_client.dart';
import 'package:submersion/core/services/garmin_connect/garmin_dive_mapper.dart';
import 'package:submersion/core/services/garmin_connect/garmin_session_store.dart';
import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/import_wizard/data/adapters/garmin_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/garmin_cloud_dive_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
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
/// is handled elsewhere in the import pipeline. Once at least one page has
/// downloaded, the fetched dives are shown in a checkbox list -- only the
/// dives left selected there are carried into the rest of the wizard.
class GarminCloudFetchStep extends ConsumerStatefulWidget {
  const GarminCloudFetchStep({
    super.key,
    required this.client,
    required this.onDivesFetched,
  });

  final GarminConnectClient? client;
  final void Function(List<GarminParsedDive> dives) onDivesFetched;

  @override
  ConsumerState<GarminCloudFetchStep> createState() =>
      _GarminCloudFetchStepState();
}

class _GarminCloudFetchStepState extends ConsumerState<GarminCloudFetchStep> {
  static const _fitParser = FitParserService();

  bool _isFetching = true;
  bool _isLoadingMore = false;
  bool _isFetchingAll = false;
  bool _hasFetched = false;
  bool _hasMorePages = true;
  int _failedCount = 0;
  String? _error;
  String? _loadMoreError;
  String? _progressText;

  final List<GarminParsedDive> _parsedDives = [];

  /// Indices into [_parsedDives] the diver wants carried into the rest of
  /// the wizard. Every newly downloaded dive is selected by default, so
  /// deselecting is an opt-out rather than an opt-in action.
  final Set<int> _selectedIndices = {};

  /// Cursor for the next unfetched listing page.
  ///
  /// Only advanced once a page's listing call has actually returned, so a
  /// page that failed is re-requested by the next Load More rather than
  /// skipped.
  int _nextPageStart = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchFirstPage());
  }

  /// Clears any dives a previous attempt loaded, WITHOUT flipping
  /// [garminCloudDivesFetchedProvider].
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
        _error = context.l10n.garminConnect_fetch_failedTitle;
      });
      _discardDives();
      return;
    }

    setState(() {
      _isFetching = true;
      _error = null;
      _parsedDives.clear();
      _selectedIndices.clear();
      _failedCount = 0;
      _hasMorePages = true;
      _nextPageStart = 0;
      // A retry starts the whole fetch over, so no paging error or spinner
      // from the previous attempt may survive into it.
      _loadMoreError = null;
      _isLoadingMore = false;
      _isFetchingAll = false;
      _progressText = context.l10n.garminConnect_fetch_listing;
    });

    try {
      final page = await client.fetchDivePage();
      if (!mounted) return;
      _nextPageStart = page.nextStart;
      _hasMorePages = page.hasMore;

      if (page.dives.isNotEmpty) {
        await _downloadPage(client, page.dives);
        if (!mounted) return;
      }

      _publishSelection();
      setState(() {
        _isFetching = false;
        _hasFetched = true;
      });
      ref.read(garminCloudDivesFetchedProvider.notifier).state = true;
    } on GarminApiException catch (e) {
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
      final page = await client.fetchDivePage(start: _nextPageStart);
      if (!mounted) return;
      _nextPageStart = page.nextStart;
      _hasMorePages = page.hasMore;

      if (page.dives.isNotEmpty) {
        await _downloadPage(client, page.dives);
        if (!mounted) return;
      }

      _publishSelection();
      setState(() => _isLoadingMore = false);
    } on GarminApiException catch (e) {
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

  /// Repeatedly loads every remaining page, so the diver doesn't have to
  /// click Load More once per page for a large account's history.
  ///
  /// Stops as soon as a page fails: the failure is already surfaced next to
  /// the Load More/Fetch All buttons by [_loadMore] itself, and continuing
  /// to hammer a failing endpoint wouldn't recover on its own.
  Future<void> _fetchAll() async {
    if (_isFetchingAll || _isLoadingMore) return;
    // The loop below stops on _loadMoreError, so an error left over from an
    // earlier page would make this button a silent no-op. Clearing it here
    // is what makes Fetch All a genuine retry after a failed page.
    setState(() {
      _isFetchingAll = true;
      _loadMoreError = null;
    });

    while (mounted && _hasMorePages && _loadMoreError == null) {
      await _loadMore();
    }

    if (mounted) setState(() => _isFetchingAll = false);
  }

  /// Downloads and parses every dive in [page] in parallel, appending
  /// successes to [_parsedDives] in the page's original order. A single
  /// dive's fetch/parse failure is skipped rather than aborting the page,
  /// matching how a single corrupt file is handled elsewhere in the import
  /// pipeline. Newly downloaded dives are selected by default.
  Future<void> _downloadPage(
    GarminConnectClient client,
    List<GarminActivitySummary> page,
  ) async {
    final alreadyProcessed = _parsedDives.length + _failedCount;
    final results = List<GarminParsedDive?>.filled(page.length, null);
    var completed = 0;

    Future<void> downloadOne(int i) async {
      try {
        final activityId = page[i].activityId;
        final bytes = await client.downloadActivityFit(activityId);
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
        // Left null; counted as a failure below.
      } finally {
        completed++;
        if (mounted) {
          setState(() {
            _progressText = context.l10n.garminConnect_fetch_fetchingDiveOf(
              alreadyProcessed + completed,
              alreadyProcessed + page.length,
            );
          });
        }
      }
    }

    await Future.wait(List.generate(page.length, downloadOne));
    if (!mounted) return;

    for (final parsed in results) {
      if (parsed == null) {
        _failedCount++;
      } else {
        _selectedIndices.add(_parsedDives.length);
        _parsedDives.add(parsed);
      }
    }
  }

  void _toggleSelected(int index) {
    setState(() {
      if (!_selectedIndices.remove(index)) _selectedIndices.add(index);
    });
    _publishSelection();
  }

  void _selectAll() {
    setState(
      () =>
          _selectedIndices.addAll(List.generate(_parsedDives.length, (i) => i)),
    );
    _publishSelection();
  }

  void _deselectAll() {
    setState(_selectedIndices.clear);
    _publishSelection();
  }

  /// Reports the currently selected dives, in fetched order, as the set to
  /// carry into the rest of the wizard.
  void _publishSelection() {
    final sortedIndices = _selectedIndices.toList()..sort();
    widget.onDivesFetched(
      List.unmodifiable(sortedIndices.map((i) => _parsedDives[i])),
    );
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
                _progressText ?? l10n.garminConnect_fetch_listing,
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
                l10n.garminConnect_fetch_failedTitle,
                style: theme.textTheme.titleLarge,
              ),
              // The no-client branch has no detail beyond the headline; it
              // sets _error to the headline itself, so guard against
              // printing the same sentence twice.
              if (_error != l10n.garminConnect_fetch_failedTitle) ...[
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
                label: Text(l10n.garminConnect_fetch_retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasFetched && _parsedDives.isEmpty) {
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
                l10n.garminConnect_fetch_foundDives(0),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (_failedCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.garminConnect_fetch_someFailed(_failedCount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_hasMorePages) ...[
                const SizedBox(height: 24),
                _buildFetchMoreFooter(theme, l10n),
              ],
            ],
          ),
        ),
      );
    }

    if (_hasFetched) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: Text(
              l10n.garminConnect_fetch_foundDives(_parsedDives.length),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          if (_failedCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Text(
                l10n.garminConnect_fetch_someFailed(_failedCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.universalImport_label_xOfYSelected(
                      _selectedIndices.length,
                      _parsedDives.length,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selectAll,
                  child: Text(l10n.universalImport_action_selectAll),
                ),
                TextButton(
                  onPressed: _deselectAll,
                  child: Text(l10n.universalImport_action_deselectAll),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GarminCloudDiveList(
              dives: _parsedDives,
              selectedIndices: _selectedIndices,
              settings: ref.watch(settingsProvider),
              onToggle: _toggleSelected,
            ),
          ),
          if (_hasMorePages) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFetchMoreFooter(theme, l10n),
            ),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// The Load More/Fetch All controls shared between the empty-results and
  /// populated-list states of the fetched view.
  Widget _buildFetchMoreFooter(ThemeData theme, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoadingMore || _isFetchingAll) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _progressText ?? l10n.garminConnect_fetch_listing,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ] else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.expand_more),
                label: Text(l10n.garminConnect_fetch_loadMore),
              ),
              OutlinedButton.icon(
                onPressed: _fetchAll,
                icon: const Icon(Icons.cloud_download),
                label: Text(l10n.garminConnect_fetch_fetchAll),
              ),
            ],
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
    );
  }
}
