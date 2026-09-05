import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/import_wizard/presentation/providers/cloud_import_page_size_provider.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/cloud_import_dive_list.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/cloud_import_dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One listing page from a cloud dive provider.
class CloudImportListingPage<TSummary> {
  const CloudImportListingPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<TSummary> items;
  final int nextCursor;
  final bool hasMore;
}

/// Provider-specific copy for the shared cloud fetch step.
class CloudImportFetchStrings {
  const CloudImportFetchStrings({
    required this.listing,
    required this.fetchingDiveOf,
    required this.failedTitle,
    required this.retry,
    required this.loadMore,
    required this.fetchAll,
    required this.foundDives,
    required this.someFailed,
  });

  factory CloudImportFetchStrings.suunto(AppLocalizations l10n) {
    return CloudImportFetchStrings(
      listing: l10n.suuntoCloud_fetch_listing,
      fetchingDiveOf: l10n.suuntoCloud_fetch_fetchingDiveOf,
      failedTitle: l10n.suuntoCloud_fetch_failedTitle,
      retry: l10n.suuntoCloud_fetch_retry,
      loadMore: l10n.suuntoCloud_fetch_loadMore,
      fetchAll: l10n.suuntoCloud_fetch_fetchAll,
      foundDives: l10n.suuntoCloud_fetch_foundDives,
      someFailed: l10n.suuntoCloud_fetch_someFailed,
    );
  }

  factory CloudImportFetchStrings.garmin(AppLocalizations l10n) {
    return CloudImportFetchStrings(
      listing: l10n.garminConnect_fetch_listing,
      fetchingDiveOf: l10n.garminConnect_fetch_fetchingDiveOf,
      failedTitle: l10n.garminConnect_fetch_failedTitle,
      retry: l10n.garminConnect_fetch_retry,
      loadMore: l10n.garminConnect_fetch_loadMore,
      fetchAll: l10n.garminConnect_fetch_fetchAll,
      foundDives: l10n.garminConnect_fetch_foundDives,
      someFailed: l10n.garminConnect_fetch_someFailed,
    );
  }

  final String listing;
  final String Function(int current, int total) fetchingDiveOf;
  final String failedTitle;
  final String retry;
  final String loadMore;
  final String fetchAll;
  final String Function(int count) foundDives;
  final String Function(int count) someFailed;
}

/// Shared fetch step for cloud dive imports.
///
/// Fetches [cloudImportPageSizeProvider] of the newest dives, offers Load
/// More for the next page of the same size, and Fetch All to walk the rest
/// of the history (which then hides the paging controls). Downloaded dives
/// are shown in a checkbox list; only the selected ones are reported.
class CloudImportFetchStep<TSummary, TParsed> extends ConsumerStatefulWidget {
  const CloudImportFetchStep({
    super.key,
    required this.hasClient,
    required this.fetchPage,
    required this.downloadPage,
    required this.diveOf,
    required this.onDivesFetched,
    required this.divesFetchedProvider,
    required this.strings,
    required this.formatError,
  });

  final bool hasClient;

  final Future<CloudImportListingPage<TSummary>> Function({
    required int cursor,
    required int pageSize,
  })
  fetchPage;

  /// Downloads and converts every summary in [page]. A null slot is a
  /// skipped failure; the shared step counts those rather than aborting.
  final Future<List<TParsed?>> Function(
    List<TSummary> page,
    void Function(int completed, int total) onProgress,
  )
  downloadPage;

  final DownloadedDive Function(TParsed parsed) diveOf;
  final void Function(List<TParsed> dives) onDivesFetched;
  final StateProvider<bool> divesFetchedProvider;
  final CloudImportFetchStrings strings;
  final String Function(Object error) formatError;

  @override
  ConsumerState<CloudImportFetchStep<TSummary, TParsed>> createState() =>
      _CloudImportFetchStepState<TSummary, TParsed>();
}

class _CloudImportFetchStepState<TSummary, TParsed>
    extends ConsumerState<CloudImportFetchStep<TSummary, TParsed>> {
  bool _isFetching = true;
  bool _isLoadingMore = false;
  bool _isFetchingAll = false;
  bool _hasFetched = false;
  bool _hasMorePages = true;
  int _failedCount = 0;
  String? _error;
  String? _loadMoreError;
  String? _progressText;

  final List<TParsed> _parsedDives = [];

  /// Indices into [_parsedDives] the diver wants carried into the rest of
  /// the wizard. Every newly downloaded dive is selected by default, so
  /// deselecting is an opt-out rather than an opt-in action.
  final Set<int> _selectedIndices = {};

  /// Cursor for the next unfetched listing page.
  ///
  /// Only advanced once a page's listing call has actually returned, so a
  /// page that failed is re-requested by the next Load More rather than
  /// skipped.
  int _nextCursor = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchFirstPage());
  }

  /// Clears any dives a previous attempt loaded, WITHOUT flipping
  /// [widget.divesFetchedProvider].
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

  int get _pageSize => ref.read(cloudImportPageSizeProvider);

  Future<void> _fetchFirstPage() async {
    if (!widget.hasClient) {
      setState(() {
        _isFetching = false;
        _error = widget.strings.failedTitle;
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
      _nextCursor = 0;
      // A retry starts the whole fetch over, so no paging error or spinner
      // from the previous attempt may survive into it.
      _loadMoreError = null;
      _isLoadingMore = false;
      _isFetchingAll = false;
      _progressText = widget.strings.listing;
    });

    try {
      final page = await widget.fetchPage(cursor: 0, pageSize: _pageSize);
      if (!mounted) return;
      _nextCursor = page.nextCursor;
      _hasMorePages = page.hasMore;

      if (page.items.isNotEmpty) {
        await _downloadPage(page.items);
        if (!mounted) return;
      }

      _publishSelection();
      setState(() {
        _isFetching = false;
        _hasFetched = true;
      });
      ref.read(widget.divesFetchedProvider.notifier).state = true;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetching = false;
        _error = widget.formatError(e);
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
    if (!widget.hasClient || _isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await widget.fetchPage(
        cursor: _nextCursor,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      _nextCursor = page.nextCursor;
      _hasMorePages = page.hasMore;

      if (page.items.isNotEmpty) {
        await _downloadPage(page.items);
        if (!mounted) return;
      }

      _publishSelection();
      setState(() => _isLoadingMore = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = widget.formatError(e);
      });
    }
  }

  /// Repeatedly loads every remaining page, so the diver doesn't have to
  /// click Load More once per page for a large account's history.
  ///
  /// Stops as soon as a page fails: the failure is already surfaced next to
  /// the Load More/Fetch All buttons by [_loadMore] itself, and continuing
  /// to hammer a failing endpoint wouldn't recover on its own. Once the
  /// history is exhausted, paging controls are hidden.
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

  Future<void> _downloadPage(List<TSummary> page) async {
    final alreadyProcessed = _parsedDives.length + _failedCount;
    final results = await widget.downloadPage(page, (completed, total) {
      if (!mounted) return;
      setState(() {
        _progressText = widget.strings.fetchingDiveOf(
          alreadyProcessed + completed,
          alreadyProcessed + total,
        );
      });
    });
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
    final strings = widget.strings;

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
                _progressText ?? strings.listing,
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
              Text(strings.failedTitle, style: theme.textTheme.titleLarge),
              // The no-client branch has no detail beyond the headline; it
              // sets _error to the headline itself, so guard against
              // printing the same sentence twice.
              if (_error != strings.failedTitle) ...[
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
                label: Text(strings.retry),
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
                strings.foundDives(0),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (_failedCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  strings.someFailed(_failedCount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_hasMorePages) ...[
                const SizedBox(height: 24),
                _buildFetchMoreFooter(theme, strings),
              ],
            ],
          ),
        ),
      );
    }

    if (_hasFetched) {
      final settings = ref.watch(settingsProvider);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: Text(
              strings.foundDives(_parsedDives.length),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          if (_failedCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Text(
                strings.someFailed(_failedCount),
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
            child: CloudImportDiveList(
              itemCount: _parsedDives.length,
              selectedIndices: _selectedIndices,
              titleOf: (index) => formatCloudDiveSummary(
                widget.diveOf(_parsedDives[index]),
                settings,
              ).title,
              subtitleOf: (index) => formatCloudDiveSummary(
                widget.diveOf(_parsedDives[index]),
                settings,
              ).subtitle,
              onToggle: _toggleSelected,
            ),
          ),
          if (_hasMorePages) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFetchMoreFooter(theme, strings),
            ),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// The Load More/Fetch All controls shared between the empty-results and
  /// populated-list states of the fetched view. Fetch All walks every
  /// remaining page and then hides this footer by flipping [_hasMorePages].
  Widget _buildFetchMoreFooter(
    ThemeData theme,
    CloudImportFetchStrings strings,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoadingMore || _isFetchingAll) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _progressText ?? strings.listing,
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
                label: Text(strings.loadMore),
              ),
              OutlinedButton.icon(
                onPressed: _fetchAll,
                icon: const Icon(Icons.cloud_download),
                label: Text(strings.fetchAll),
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
