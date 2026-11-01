import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_editor.dart';
import 'package:submersion/features/query/presentation/providers/entity_search_providers.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/features/query/presentation/widgets/search_everywhere_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Finds a list's search field, for tests.
Key entitySearchFieldKey(QuerySubject subject) =>
    ValueKey('entity-search-field-${subject.name}');

/// Finds a list's Close search button, for tests.
Key entitySearchCloseKey(QuerySubject subject) =>
    ValueKey('entity-search-close-${subject.name}');

/// A list's search row (#3882), the Dives row for every other list: plain
/// words, quoted phrases and the query language of [root] in one field,
/// filtering the list as the diver types, with a way to search everything
/// beneath it. It sits under the list's app bar, outside its loading and
/// empty states, and shows while opened or while the list has a query.
///
/// The list owns the query: [query] is what it filters by now, and
/// [onChanged] receives each clean tree once typing rests.
class EntitySearchHeader extends ConsumerStatefulWidget {
  const EntitySearchHeader({
    super.key,
    required this.subject,
    required this.root,
    required this.query,
    required this.onChanged,
    this.hintText,
    this.alwaysShown = false,
  });

  final QuerySubject subject;
  final QueryEntity root;
  final QueryNode? query;
  final ValueChanged<QueryNode?> onChanged;

  /// Defaults to the shared hint.
  final String? hintText;

  /// Keeps the row up with no query and no open request, for a page that
  /// has always shown its search field; the Close button then clears
  /// rather than hides.
  final bool alwaysShown;

  @override
  ConsumerState<EntitySearchHeader> createState() => _EntitySearchHeaderState();
}

class _EntitySearchHeaderState extends ConsumerState<EntitySearchHeader> {
  final _focus = FocusNode();
  Timer? _debounce;

  /// The field's latest clean tree, ahead of the debounced write.
  QueryNode? _local;

  /// What the diver typed, parsed or not: what Search everything sends.
  String _text = '';

  /// Empties the field after Close, whose write the field cannot see when
  /// the committed tree was already null.
  QueryTextOverride? _override;

  @override
  void initState() {
    super.initState();
    _local = widget.query;
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeFocusRequest());
  }

  @override
  void didUpdateWidget(EntitySearchHeader old) {
    super.didUpdateWidget(old);
    // Only a change from outside (a chip removed, a saved query applied)
    // replaces the field; the list echoing a typed query back must not
    // revert what the diver is typing next.
    if (widget.query != old.query && widget.query != _local) {
      _debounce?.cancel();
      _local = widget.query;
      _text = '';
      // Close's empty text must not outlive it: a row hidden by Close and
      // shown again by this query builds a new field, which would apply it
      // over the printed query.
      _override = null;
    }
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
      ref.read(entitySearchOpenProvider(widget.subject).notifier).state = true;
    }
    setState(() {});
  }

  void _takeFocusRequest() {
    if (!mounted || !_onScreen) return;
    final pending = entitySearchFocusPendingProvider(widget.subject);
    if (!ref.read(pending)) return;
    ref.read(pending.notifier).state = false;
    // After the frame: the field may only now be built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Whether this row is the one the diver can see. The request is keyed by
  /// subject, and two lists of one subject can be mounted at once: the Trips
  /// nav page under the Trips list that See all pushes. The covered one, or
  /// one on an inactive nav branch, must leave the request to the other.
  bool get _onScreen =>
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      TickerMode.valuesOf(context).enabled;

  void _onQueryChanged(QueryNode? node) {
    _local = node;
    _debounce?.cancel();
    _debounce = Timer(kEntitySearchDebounce, () {
      if (mounted) widget.onChanged(node);
    });
  }

  /// Close: the row hides (unless [EntitySearchHeader.alwaysShown]) and the
  /// query clears, text still waiting on the debounce included.
  void _close() {
    _debounce?.cancel();
    _focus.unfocus();
    ref.read(entitySearchOpenProvider(widget.subject).notifier).state = false;
    setState(() {
      _local = null;
      _text = '';
      _override = QueryTextOverride('');
    });
    if (widget.query != null) widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(entitySearchFocusPendingProvider(widget.subject), (
      _,
      pending,
    ) {
      if (pending) _takeFocusRequest();
    });
    final visible =
        widget.alwaysShown ||
        widget.query != null ||
        ref.watch(entitySearchOpenProvider(widget.subject));
    if (!visible) {
      // Hidden by the icon rather than Close: text not yet written, and the
      // write it was waiting on, go with the row, as they do on Close.
      _debounce?.cancel();
      _local = null;
      _text = '';
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final showEverywhere = _text.trim().isNotEmpty && _focus.hasFocus;
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
                  context: watchQueryEditorContext(context, ref, widget.root),
                  value: _local,
                  onChanged: _onQueryChanged,
                  hintText: widget.hintText ?? l10n.search_fieldHint,
                  describeError: (e) => describeQueryError(l10n, e),
                  fieldKey: entitySearchFieldKey(widget.subject),
                  focusNode: _focus,
                  onTextChanged: (text) => setState(() => _text = text),
                  textOverride: _override,
                  onEscape: _close,
                ),
              ),
              IconButton(
                key: entitySearchCloseKey(widget.subject),
                tooltip: l10n.search_closeTooltip,
                icon: const Icon(Icons.close),
                onPressed: _close,
              ),
            ],
          ),
        ),
        if (showEverywhere) SearchEverywhereRow(text: _text),
      ],
    );
  }
}
