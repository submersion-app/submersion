import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/global_search_navigation.dart';
import 'package:submersion/features/global_search/presentation/global_search_text_reader.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/global_search/presentation/widgets/global_search_section_view.dart';
import 'package:submersion/features/query/presentation/entity_query_editor.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';

/// The field and results stop growing here on a wide window.
const double _kMaxResultsWidth = 720;

/// One search over every kind of record (#3882). The field is the Dives
/// field, query language, completions and all, reading the text against every
/// record type at once.
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _focus = FocusNode();

  /// What the field shows.
  String _text = '';

  /// The last text a record type could read. Half a query (`depth >`) leaves
  /// the results of what came before it up, as the Dives field does.
  String _query = '';
  QueryTextOverride? _override;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() => _override = QueryTextOverride('', commit: true));
    _focus.requestFocus();
  }

  void _focusField() {
    _focus.requestFocus();
    setState(() => _override = QueryTextOverride(_text, selectAll: true));
  }

  void _open(GlobalSearchKind kind, String id) =>
      context.pushOrReturnTo(globalSearchLocation(kind, id));

  @override
  Widget build(BuildContext context) {
    ref.listen(globalSearchFocusTickProvider, (_, _) => _focusField());
    final l10n = context.l10n;
    // Dives stands in as the root: the reader answers for every type.
    final editorContext = watchQueryEditorContext(
      context,
      ref,
      diveQueryEntity,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nav_search)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxResultsWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: QueryTextField(
                  fieldKey: const ValueKey('global-search-field'),
                  context: editorContext,
                  textReader: GlobalSearchTextReader(editorContext),
                  value: null,
                  onChanged: (_) {},
                  onTextChanged: (text) => setState(() => _text = text),
                  onTextAccepted: (text) => setState(() => _query = text),
                  hintText: l10n.globalSearch_hint,
                  clearTooltip: l10n.globalSearch_clear,
                  describeError: (e) => describeQueryError(l10n, e),
                  focusNode: _focus,
                  autofocus: true,
                  textOverride: _override,
                  // Empty leaves Esc to whatever sits outside the field.
                  onEscape: _text.isEmpty ? null : _clear,
                ),
              ),
            ),
          ),
          Expanded(
            child: DebouncedSearchResults<GlobalSearchSection>(
              query: _query.trim(),
              watchProvider: (ref, text) =>
                  ref.watch(globalSearchProvider(text)),
              dataBuilder: _results,
              emptyBuilder: (context, text) =>
                  _Message(l10n.globalSearch_noResults(text)),
              errorBuilder: (context, error) => _Message(
                error is GlobalSearchRefused
                    ? describeQueryError(l10n, error.error)
                    : l10n.globalSearch_failed,
              ),
              emptyQueryBuilder: (context) =>
                  _Message(l10n.globalSearch_prompt, icon: Icons.search),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, List<GlobalSearchSection> sections) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxResultsWidth),
            child: GlobalSearchSectionView(
              // Per search, so an expanded section does not outlive it.
              key: ValueKey((section.kind, section.query)),
              section: section,
              onOpen: (id) => _open(section.kind, id),
              onSeeAll: section.hasList
                  ? () => openGlobalSearchList(
                      context,
                      ref,
                      section.kind,
                      section.query,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// The centred line shown in place of results.
class _Message extends StatelessWidget {
  const _Message(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
