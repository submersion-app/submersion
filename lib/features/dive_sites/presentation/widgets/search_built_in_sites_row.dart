import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kSearchBuiltInSitesRowKey = ValueKey('search-built-in-sites-row');

/// The row under the Sites search field that takes the typed words to the
/// built-in catalogue: `Search built-in sites for "text"`. It opens the
/// Import page with that search run.
///
/// The Sites list searches the diver's own sites. A diver who types the
/// name of a site they do not have yet (a wreck to read about before a
/// trip) finds nothing there, and this is the way on.
///
/// Absent in demo mode, where the Import page is sealed.
class SearchBuiltInSitesRow extends ConsumerWidget {
  const SearchBuiltInSitesRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(demoModeActiveProvider)) return const SizedBox.shrink();
    final query = text.trim();
    return ListTile(
      key: kSearchBuiltInSitesRowKey,
      dense: true,
      leading: const Icon(Icons.public),
      title: Text(
        context.l10n.diveSites_search_builtIn(query),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
        Uri(path: '/sites/import', queryParameters: {'q': query}).toString(),
      ),
    );
  }
}

/// The Sites list's own rows under its search field, for
/// `EntitySearchHeader.extraRows`: the built-in search, when what is typed
/// is plain words.
///
/// The catalogue search matches words against names and places. It does
/// not read the Sites query language, so a field condition
/// (`maxDepth > 20`) or text that does not parse yet is not handed over.
/// What is handed over is the words as parsed, not the text as typed: a
/// quoted phrase arrives without its quotes, which the catalogue search
/// would take for part of a word.
List<Widget> sitesSearchExtraRows(String text, QueryNode? parsed) {
  final words = plainSearchWords(parsed);
  return [if (words != null) SearchBuiltInSitesRow(text: words)];
}

/// The words of a parsed search that is words alone, joined by spaces, or
/// null when it is anything else: a field condition, a choice between
/// alternatives, a negation, or nothing parsed.
String? plainSearchWords(QueryNode? parsed) {
  final words = switch (parsed) {
    TextNode(:final words) => words,
    AndNode(:final children)
        when children.isNotEmpty &&
            children.every((child) => child is TextNode) =>
      [for (final child in children.cast<TextNode>()) ...child.words],
    _ => const <String>[],
  };
  final joined = words.map((word) => word.trim()).where((w) => w.isNotEmpty);
  return joined.isEmpty ? null : joined.join(' ');
}
