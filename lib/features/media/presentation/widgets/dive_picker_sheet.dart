import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_search.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_picker_row.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/utils/log_failure.dart';

/// Modal dive picker used by "Move to dive" and inbox linking. Resolves to
/// the chosen dive id, or null on dismiss.
Future<String?> showDivePickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DivePickerSheet(),
  );
}

class _DivePickerSheet extends ConsumerStatefulWidget {
  const _DivePickerSheet();

  @override
  ConsumerState<_DivePickerSheet> createState() => _DivePickerSheetState();
}

class _DivePickerSheetState extends ConsumerState<_DivePickerSheet> {
  /// How close to the end of the list the next page starts loading.
  static const _loadMoreExtent = 400.0;

  /// Null until the first page of [_query] has arrived. The rows of the
  /// previous search stay here until then, so typing does not blank the list.
  List<DivePickerRow>? _rows;

  /// The search [_rows] answers, which trails [_query] while a search runs.
  String _rowsQuery = '';
  String _query = '';
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _failed = false;
  Timer? _searchDebounce;

  /// Counts searches, so an answer to an earlier one can be told apart from
  /// the one the list is waiting for, and dropped.
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    _startFirstPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _startFirstPage() =>
      logFailure(_loadFirstPage(), _DivePickerSheetState, 'load');

  void _startNextPage() =>
      logFailure(_loadNextPage(), _DivePickerSheetState, 'load more');

  Future<List<DivePickerRow>> _fetch(
    String query, {
    DiveSummaryCursor? cursor,
  }) async {
    // Read before the first await: the sheet can close during it.
    final repository = ref.read(diveRepositoryProvider);
    // The validated id, as every diver-scoped read uses: a stale raw id
    // (a deleted diver) would list nothing, or none of this diver's dives.
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    return repository.getDivePickerRows(
      diverId: diverId,
      query: query,
      cursor: cursor,
    );
  }

  Future<void> _loadFirstPage() async {
    final searchId = ++_searchId;
    try {
      final query = _query;
      final rows = await _fetch(query);
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _rows = rows;
        _rowsQuery = query;
        _hasMore = rows.length >= kDivePickerPageSize;
      });
    } catch (_) {
      if (mounted && searchId == _searchId) {
        // Not the previous search's rows: they do not match what is typed.
        setState(() {
          _rows = null;
          _failed = true;
        });
      }
      rethrow;
    }
  }

  Future<void> _loadNextPage() async {
    final rows = _rows;
    if (rows == null || !_hasMore || _loadingMore) return;
    final searchId = _searchId;
    setState(() {
      _loadingMore = true;
      _failed = false;
    });
    try {
      final page = await _fetch(_query, cursor: rows.last.cursor);
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _rows = [...rows, ...page];
        _hasMore = page.length >= kDivePickerPageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && searchId == _searchId) {
        setState(() {
          _loadingMore = false;
          _failed = true;
        });
      }
      rethrow;
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(kDiveSearchDebounce, () {
      final query = value.trim();
      if (query == _query) return;
      setState(() {
        _query = query;
        _hasMore = false;
        _loadingMore = false;
        _failed = false;
      });
      _startFirstPage();
    });
  }

  void _retry() {
    if (_rows != null) return _startNextPage();
    setState(() => _failed = false);
    _startFirstPage();
  }

  /// A failed page waits for Retry: retrying on every scroll would keep
  /// hitting a read that is already failing.
  bool _onScroll(ScrollNotification notification) {
    if (!_failed && notification.metrics.extentAfter < _loadMoreExtent) {
      _startNextPage();
    }
    return false;
  }

  String _label(DivePickerRow dive) {
    final parts = <String>[
      if (dive.diveNumber != null) '#${dive.diveNumber}',
      if (dive.name != null && dive.name!.isNotEmpty)
        dive.name!
      else if (dive.siteName != null)
        dive.siteName!,
    ];
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  context.l10n.media_divePicker_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.l10n.media_divePicker_search,
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              Expanded(child: _buildList(context, units)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, UnitFormatter units) {
    final rows = _rows;
    if (rows == null) {
      return _failed
          ? Center(child: _LoadFailed(onRetry: _retry))
          : const Center(child: CircularProgressIndicator());
    }
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _rowsQuery.isEmpty
                ? context.l10n.preDive_link_noDives
                : context.l10n.preDive_link_noDivesMatch(_rowsQuery),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final hasFooter = _failed || _hasMore;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.builder(
        // A search's rows start at the top, not at the old scroll offset.
        key: ValueKey(_rowsQuery),
        itemCount: rows.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == rows.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _failed
                    ? _LoadFailed(onRetry: _retry)
                    : const CircularProgressIndicator(),
              ),
            );
          }
          final dive = rows[index];
          return ListTile(
            title: Text(_label(dive)),
            subtitle: Text(units.formatDate(dive.dateTime)),
            onTap: () => Navigator.of(context).pop(dive.id),
          );
        },
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.common_error_tryAgain, textAlign: TextAlign.center),
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.diveLog_error_retry),
          ),
        ],
      ),
    );
  }
}
