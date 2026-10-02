import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/close_dive_search.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_jump_list.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_scope_toggle.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kDiveSearchFieldKey = ValueKey('dive-search-field');
const kDiveSearchRefineKey = ValueKey('dive-search-refine');
const kDiveSearchCloseKey = ValueKey('dive-search-close');
const kDiveSearchInsightsKey = ValueKey('dive-search-insights');

/// The dive list's one search row (#2773): plain words, quoted phrases and
/// query syntax in one field, filtering the list as the diver types. It
/// sits under every layout's app bar, outside the list's loading and empty
/// states, and shows while opened or while anything is filtered.
class DiveSearchHeader extends ConsumerStatefulWidget {
  const DiveSearchHeader({super.key, required this.onOpenDive});

  /// Opens one dive, the way tapping its list row does.
  final ValueChanged<DiveSummary> onOpenDive;

  @override
  ConsumerState<DiveSearchHeader> createState() => _DiveSearchHeaderState();
}

class _DiveSearchHeaderState extends ConsumerState<DiveSearchHeader> {
  final _focus = FocusNode();
  Timer? _debounce;

  /// The field's latest clean tree, ahead of the debounced write.
  QueryNode? _local;

  @override
  void initState() {
    super.initState();
    _local = ref.read(diveFilterProvider).query;
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeFocusRequest());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Focusing the field opens the row, so clearing the text never
    // collapses it under the caret.
    if (_focus.hasFocus) {
      ref.read(diveSearchBarOpenProvider.notifier).state = true;
    }
    setState(() {});
  }

  void _takeFocusRequest() {
    if (!mounted || !ref.read(diveSearchFocusPendingProvider)) return;
    ref.read(diveSearchFocusPendingProvider.notifier).state = false;
    // After the frame: the field may only now be built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onQueryChanged(QueryNode? node) {
    setState(() => _local = node);
    _debounce?.cancel();
    _debounce = Timer(kDiveSearchDebounce, () {
      final notifier = ref.read(diveFilterProvider.notifier);
      // Read at write time, so a change made during the debounce survives.
      notifier.state = notifier.state.copyWith(
        query: node,
        clearQuery: node == null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(diveSearchFocusPendingProvider, (_, pending) {
      if (pending) _takeFocusRequest();
    });
    ref.listen<DiveFilterState>(diveFilterProvider, (previous, next) {
      // Only a change to the QUERY from outside (a chip removed, a saved
      // search loaded) replaces the text; another axis changing mid-debounce
      // must not revert what the diver is typing.
      if (previous?.query == next.query || next.query == _local) return;
      _debounce?.cancel();
      setState(() => _local = next.query);
    });

    if (!ref.watch(diveSearchBarVisibleProvider)) {
      return const SizedBox.shrink();
    }
    final filter = ref.watch(diveFilterProvider);
    final l10n = context.l10n;
    final editorContext = QueryEditorContext(
      registry: appQueryRegistry,
      root: diveQueryEntity,
      prefs: ref.watch(queryUnitPrefsProvider),
      names: ref.watch(queryNameIndexProvider).value ?? NameIndex.empty,
      labels: AppQueryLabels(context),
      now: DateTime.now,
    );
    final panelAxes = filter.panelAxisCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: QueryTextField(
                  context: editorContext,
                  value: _local,
                  onChanged: _onQueryChanged,
                  hintText: l10n.diveLog_search_fieldHint,
                  describeError: (e) => describeQueryError(l10n, e),
                  fieldKey: kDiveSearchFieldKey,
                  focusNode: _focus,
                  onEscape: () => closeDiveSearch(context, ref),
                ),
              ),
              IconButton(
                key: kDiveSearchRefineKey,
                tooltip: l10n.diveLog_search_refineTooltip,
                icon: Badge(
                  isLabelVisible: panelAxes > 0,
                  label: Text('$panelAxes'),
                  child: const Icon(Icons.tune),
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DiveFilterSheet(ref: ref),
                ),
              ),
              IconButton(
                key: kDiveSearchCloseKey,
                tooltip: l10n.diveLog_search_closeTooltip,
                icon: const Icon(Icons.close),
                onPressed: () => closeDiveSearch(context, ref),
              ),
            ],
          ),
        ),
        if (_focus.hasFocus && _local != null)
          DiveJumpList(query: _local!, onOpen: widget.onOpenDive),
        if (panelAxes > 0) const DiveSearchScopeToggle(),
      ],
    );
  }
}
