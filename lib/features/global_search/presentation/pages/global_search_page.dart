import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/global_search_navigation.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/global_search/presentation/widgets/global_search_section_view.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';

/// Results stop growing here on a wide window: a row is a line of text.
const double _kMaxResultsWidth = 720;

/// One search over every kind of record (#3882). The field reads what the
/// Dives field reads: words, quoted phrases and query syntax.
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    _focus.requestFocus();
  }

  void _focusField() {
    _focus.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _open(GlobalSearchHit hit) =>
      context.pushOrReturnTo(globalSearchHitLocation(hit));

  @override
  Widget build(BuildContext context) {
    ref.listen(globalSearchFocusTickProvider, (_, _) => _focusField());
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => CallbackShortcuts(
            bindings: {
              // Empty leaves Esc to whatever sits outside the field.
              if (value.text.isNotEmpty)
                const SingleActivator(LogicalKeyboardKey.escape): _clear,
            },
            child: TextField(
              key: const ValueKey('global-search-field'),
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.globalSearch_hint,
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.globalSearch_clear,
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: _controller,
        builder: (context, value, _) =>
            DebouncedSearchResults<GlobalSearchSection>(
              query: value.text.trim(),
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
              onOpen: _open,
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
