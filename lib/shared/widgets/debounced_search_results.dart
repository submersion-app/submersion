import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A widget that debounces search queries and caches the last successful
/// results to avoid spinner churn while typing.
///
/// Wraps a [FutureProvider.family]-backed search with two mitigations:
///   1. The raw [query] is debounced before the provider is watched, reducing
///      the number of async operations triggered during fast typing.
///   2. While a new query is loading, the last successful results remain
///      visible with a subtle linear progress indicator, instead of replacing
///      the entire results list with a spinner.
class DebouncedSearchResults<T> extends ConsumerStatefulWidget {
  /// The raw, un-debounced search query (e.g. from a [SearchDelegate] or
  /// [TextField.onChanged]).
  final String query;

  /// How long to wait after the last keystroke before triggering a search.
  final Duration debounceDuration;

  /// Watches the appropriate search provider for [query] and returns the
  /// current [AsyncValue]. Called with the **debounced** query.
  final AsyncValue<List<T>> Function(WidgetRef ref, String query) watchProvider;

  /// Builds the result list from successfully loaded items.
  final Widget Function(BuildContext context, List<T> items) dataBuilder;

  /// Builds the empty-results view (e.g. "No results for X").
  final Widget Function(BuildContext context, String query) emptyBuilder;

  /// Builds the error view.
  final Widget Function(BuildContext context, Object error) errorBuilder;

  /// Optional widget shown when the query is empty. If null, a [SizedBox.shrink]
  /// is returned for empty queries.
  final Widget Function(BuildContext context)? emptyQueryBuilder;

  const DebouncedSearchResults({
    super.key,
    required this.query,
    this.debounceDuration = const Duration(milliseconds: 300),
    required this.watchProvider,
    required this.dataBuilder,
    required this.emptyBuilder,
    required this.errorBuilder,
    this.emptyQueryBuilder,
  });

  @override
  ConsumerState<DebouncedSearchResults<T>> createState() =>
      _DebouncedSearchResultsState<T>();
}

class _DebouncedSearchResultsState<T>
    extends ConsumerState<DebouncedSearchResults<T>> {
  Timer? _debounceTimer;
  String _debouncedQuery = '';
  List<T>? _lastResults;

  @override
  void initState() {
    super.initState();
    _debouncedQuery = widget.query;
  }

  @override
  void didUpdateWidget(DebouncedSearchResults<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _debounceTimer?.cancel();
      if (widget.query.isEmpty) {
        // Clear immediately — no debounce needed for empty queries
        setState(() {
          _debouncedQuery = '';
          _lastResults = null;
        });
      } else {
        _debounceTimer = Timer(widget.debounceDuration, () {
          if (mounted) {
            setState(() => _debouncedQuery = widget.query);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_debouncedQuery.isEmpty) {
      _lastResults = null;
      if (widget.emptyQueryBuilder != null) {
        return widget.emptyQueryBuilder!(context);
      }
      return const SizedBox.shrink();
    }

    final searchAsync = widget.watchProvider(ref, _debouncedQuery);

    return searchAsync.when(
      data: (items) {
        _lastResults = items;
        if (items.isEmpty) {
          return widget.emptyBuilder(context, _debouncedQuery);
        }
        return widget.dataBuilder(context, items);
      },
      loading: () {
        // Show cached results with a progress indicator instead of a spinner
        if (_lastResults != null && _lastResults!.isNotEmpty) {
          return Column(
            children: [
              const LinearProgressIndicator(),
              Expanded(child: widget.dataBuilder(context, _lastResults!)),
            ],
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, _) => widget.errorBuilder(context, error),
    );
  }
}
