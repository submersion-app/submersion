import 'package:flutter/material.dart';

import 'package:submersion/core/platform/desktop_target_platform.dart';
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
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

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
  void initState() {
    super.initState();
    // A request made before the page was up (a list's Search everything
    // row, pushing this page) is taken now.
    final request = ref.read(globalSearchRequestProvider);
    if (request != null) {
      _text = request.text;
      _override = QueryTextOverride(request.text, commit: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(globalSearchRequestProvider.notifier).state = null;
      });
    }
    // Ctrl+K pressed before the page was up: the field takes the caret once
    // it is built, autofocus or not.
    if (ref.read(globalSearchFocusPendingProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _takeFocusRequest();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// On a phone or tablet under the bottom bar's width the on-screen keyboard
  /// covers the bar, and this page, a nav destination, has no back arrow: the
  /// keyboard comes up only when asked for there (#4813). A narrow desktop
  /// window has no on-screen keyboard, so it keeps the focus. Reads only the
  /// size, so the keyboard's own inset does not rebuild the page.
  bool get _keyboardCoversNav =>
      !isDesktopTargetPlatform(Theme.of(context).platform) &&
      MediaQuery.sizeOf(context).width < ResponsiveBreakpoints.desktop;

  void _take(GlobalSearchRequest request) {
    setState(() {
      _text = request.text;
      _override = QueryTextOverride(request.text, commit: true);
    });
    if (!_keyboardCoversNav) _focus.requestFocus();
    ref.read(globalSearchRequestProvider.notifier).state = null;
  }

  void _clear() {
    setState(() => _override = QueryTextOverride('', commit: true));
    _focus.requestFocus();
  }

  /// Puts the caret in the field with its text selected, for Ctrl+K, and
  /// clears the request.
  void _takeFocusRequest() {
    _focus.requestFocus();
    setState(() => _override = QueryTextOverride(_text, selectAll: true));
    ref.read(globalSearchFocusPendingProvider.notifier).state = false;
  }

  void _open(GlobalSearchKind kind, String id) =>
      context.pushOrReturnTo(globalSearchLocation(kind, id));

  @override
  Widget build(BuildContext context) {
    ref.listen(globalSearchFocusPendingProvider, (_, wanted) {
      if (wanted) _takeFocusRequest();
    });
    ref.listen(globalSearchRequestProvider, (_, request) {
      if (request != null) _take(request);
    });
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
                // A tap anywhere else puts the keyboard away and brings the
                // bottom bar back: the app's actions do that for every field.
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
                  autofocus: !_keyboardCoversNav,
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
      // Each type keeps its section from one search to the next, wherever it
      // moves, so its rows stay up while the next search's load.
      findChildIndexCallback: (key) {
        final index = sections.indexWhere((s) => ValueKey(s.kind) == key);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) {
        final section = sections[index];
        return Center(
          key: ValueKey(section.kind),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxResultsWidth),
            child: GlobalSearchSectionView(
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
