import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chips.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/show_refine_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/close_dive_search.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_ask_notice.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_ask_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_jump_list.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_scope_toggle.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
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
  const DiveSearchHeader({super.key, required this.onOpenDive, this.onEscape});

  /// Opens one dive, the way tapping its list row does.
  final ValueChanged<DiveSummary> onOpenDive;

  /// Replaces Escape's close-and-clear while set; the list passes its
  /// selection exit, so Esc leaves selection mode first, as it does there.
  final VoidCallback? onEscape;

  @override
  ConsumerState<DiveSearchHeader> createState() => _DiveSearchHeaderState();
}

class _DiveSearchHeaderState extends ConsumerState<DiveSearchHeader> {
  final _focus = FocusNode();
  Timer? _debounce;

  /// The field's latest clean tree, ahead of the debounced write.
  QueryNode? _local;

  /// What the jump list searches: [_local] once typing rests, so it runs
  /// one whole-log query per pause rather than one per keystroke.
  QueryNode? _jumpQuery;

  /// Whether the field's text parses. While it does not, the list keeps
  /// the last valid query but the jump rows hide: they would answer text
  /// the diver has since changed.
  bool _fieldValid = true;

  /// What the diver typed, parsed or not: the sentence Ask would send.
  /// Cleared when the field is re-printed from outside (an answer, a chip
  /// removed), so the Ask row offers only text the diver wrote.
  String _text = '';

  /// Puts a sentence back into the field without applying it (Undo).
  QueryTextOverride? _textOverride;

  @override
  void initState() {
    super.initState();
    _local = ref.read(diveFilterProvider).query;
    _jumpQuery = _local;
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

  /// Writes a typed query still waiting on the debounce now, so a surface
  /// that reads the filter next (the Refine panel) starts from it.
  void _flushPending() {
    if (_debounce?.isActive != true) return;
    _debounce!.cancel();
    final node = _local;
    setState(() => _jumpQuery = node);
    final notifier = ref.read(diveFilterProvider.notifier);
    notifier.state = notifier.state.copyWith(
      query: node,
      clearQuery: node == null,
    );
  }

  void _onQueryChanged(QueryNode? node) {
    // An emptied field hides the jump rows now, not after the debounce.
    setState(() {
      _local = node;
      if (node == null) _jumpQuery = null;
    });
    _debounce?.cancel();
    _debounce = Timer(kDiveSearchDebounce, () {
      if (mounted && _fieldValid) setState(() => _jumpQuery = node);
      final notifier = ref.read(diveFilterProvider.notifier);
      // Read at write time, so a change made during the debounce survives.
      notifier.state = notifier.state.copyWith(
        query: node,
        clearQuery: node == null,
      );
    });
  }

  void _onValidityChanged(bool valid) {
    _fieldValid = valid;
    if (!valid) {
      setState(() => _jumpQuery = null);
    } else if (_debounce?.isActive != true) {
      // Back to the committed text: nothing new is written, so the rows
      // return now rather than with the next debounce.
      setState(() => _jumpQuery = _local);
    }
  }

  void _onTextChanged(String text) {
    setState(() => _text = text);
    final ask = ref.read(diveAskProvider.notifier);
    // The diver typed on: their newer text wins over an answer on its way.
    ask.cancel();
    // Editing moves away from the answer shown, so its Undo would throw
    // the edit away.
    if (ref.read(diveAskProvider).answer != null) ask.dismiss();
    // Warm the model once the diver types, not on every focus of search.
    if (text.trim().isNotEmpty) ask.prepare();
  }

  Future<void> _ask() async {
    final sentence = _text.trim();
    if (sentence.isEmpty || !ref.read(exploreEnabledProvider)) return;
    // The words typed so far apply now, as typed text would: the filter is
    // settled before the model is called, so no answer meets words still
    // waiting on the debounce, and an answer's Undo goes back to them.
    _flushPending();
    final route = await ref.read(diveAskProvider.notifier).ask(sentence);
    if (!mounted) return;
    final ask = ref.read(diveAskProvider);
    if (ask.error == null && !ask.running && _text.trim() == sentence) {
      setState(() => _text = '');
    }
    if (route != null && mounted) context.go(route);
  }

  QueryEditorContext _editorContext({bool watch = false}) => QueryEditorContext(
    registry: appQueryRegistry,
    root: diveQueryEntity,
    prefs: watch
        ? ref.watch(queryUnitPrefsProvider)
        : ref.read(queryUnitPrefsProvider),
    names:
        (watch
                ? ref.watch(queryNameIndexProvider)
                : ref.read(queryNameIndexProvider))
            .value ??
        NameIndex.empty,
    labels: AppQueryLabels(context),
    now: DateTime.now,
  );

  void _undoAsk() {
    final sentence = ref.read(diveAskProvider.notifier).undo();
    if (sentence == null) return;
    setState(() {
      _text = sentence;
      _textOverride = QueryTextOverride(sentence);
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(diveSearchFocusPendingProvider, (_, pending) {
      if (pending) _takeFocusRequest();
    });
    // A close or clear from anywhere drops what is still waiting on the
    // debounce; it would otherwise land after the clear and reopen the row.
    ref.listen<int>(diveSearchClearTickProvider, (_, _) {
      _debounce?.cancel();
      ref.read(diveAskProvider.notifier).reset();
      setState(() {
        _local = _jumpQuery = null;
        _text = '';
      });
    });
    // A new answer wins over words still waiting on the debounce, even
    // when its query equals the one already applied (the filter listener
    // below sees no change then).
    ref.listen<AskState>(diveAskProvider, (previous, next) {
      final answer = next.answer;
      if (answer == null || identical(answer, previous?.answer)) return;
      final query = answer.compiled.query;
      if (answer.compiled.subject != ParsedSubject.dives || query == null) {
        return;
      }
      // Print the answer here too: one equal to the query already applied
      // writes nothing the filter listener sees, and the field would keep
      // the sentence while the answer filters the list. The override also
      // covers a sentence that never parsed, whose committed tree may
      // already equal the answer.
      setState(() {
        _local = _jumpQuery = query;
        _fieldValid = true;
        _text = '';
        _textOverride = QueryTextOverride(
          _editorContext().printer.print(query),
        );
      });
    });
    ref.listen<DiveFilterState>(diveFilterProvider, (previous, next) {
      // Only a change to the QUERY from outside (a chip removed, a saved
      // search loaded) replaces the text; another axis changing mid-debounce
      // must not revert what the diver is typing.
      if (previous?.query == next.query || next.query == _local) return;
      _debounce?.cancel();
      setState(() {
        _local = _jumpQuery = next.query;
        _text = '';
      });
    });

    if (!ref.watch(diveSearchBarVisibleProvider)) {
      return const SizedBox.shrink();
    }
    // Kept live while the row is up, as Explore's page kept it: unlistened,
    // the legacy buddy names pause, and a dive write would only mark them
    // due, so the next Ask would resolve against stale names. Only where
    // Ask can run: elsewhere nothing reads them.
    if (ref.watch(exploreEnabledProvider)) {
      ref.listen(exploreNameIndexProvider, (_, _) {});
    }
    final filter = ref.watch(diveFilterProvider);
    final l10n = context.l10n;
    final editorContext = _editorContext(watch: true);
    final panelAxes = filter.panelAxisCount;
    final ask = ref.watch(diveAskProvider);
    // An error stays with the text that caused it: once the field is
    // re-printed from outside, there is no sentence left to retry.
    final showAskRow =
        (_text.trim().isNotEmpty && (_focus.hasFocus || ask.error != null)) ||
        ask.running;
    void openInsights() {
      // What applies, not what is set: Insights has no "All dives" toggle
      // to show a suspension with.
      ref.read(insightsFilterProvider.notifier).state = filter.effective;
      context.go('/insights');
    }

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
                  onValidityChanged: _onValidityChanged,
                  onTextChanged: _onTextChanged,
                  textOverride: _textOverride,
                  shortcuts: {
                    if (ref.watch(exploreEnabledProvider))
                      platformShortcut(LogicalKeyboardKey.enter): _ask,
                  },
                  onEscape:
                      widget.onEscape ?? () => closeDiveSearch(context, ref),
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
                onPressed: () {
                  _flushPending();
                  showRefinePanel(context, filterProvider: diveFilterProvider);
                },
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
        if (showAskRow) DiveAskRow(text: _text, onAsk: _ask),
        DiveAskNotice(
          onUndo: _undoAsk,
          onOpenList: (route) => context.go(route),
        ),
        if (_focus.hasFocus && _jumpQuery != null)
          DiveJumpList(
            query: _jumpQuery!,
            onOpen: (dive) {
              // The jump is done: close the rows it came from.
              _focus.unfocus();
              widget.onOpenDive(dive);
            },
          ),
        if (panelAxes > 0) const DiveSearchScopeToggle(),
        if (filter.hasActiveFilters)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4),
            // The row's own width: on desktop it sits in the narrow master
            // pane of a wide window.
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: activeDiveFilterChips(
                          context,
                          ref,
                          diveFilterProvider,
                        ),
                      ),
                    ),
                  ),
                  // An icon on narrow layouts, so the chips keep the row.
                  if (constraints.maxWidth < 600)
                    IconButton(
                      key: kDiveSearchInsightsKey,
                      tooltip: l10n.diveLog_search_openInsights,
                      icon: const Icon(Icons.insights),
                      onPressed: openInsights,
                    )
                  else
                    TextButton(
                      key: kDiveSearchInsightsKey,
                      onPressed: openInsights,
                      child: Text(l10n.diveLog_search_openInsights),
                    ),
                  TextButton(
                    onPressed: () =>
                        closeDiveSearch(context, ref, collapse: false),
                    child: Text(l10n.diveLog_filterChip_clearAll),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
