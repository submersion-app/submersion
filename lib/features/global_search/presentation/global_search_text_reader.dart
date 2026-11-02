import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/presentation/query_completions.dart'
    as query
    show completionsAt;
import 'package:submersion/core/query/presentation/query_completions.dart'
    show Completion, kMaxQueryCompletions;
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/features/global_search/data/global_search_plan.dart';
import 'package:submersion/features/global_search/data/global_search_sources.dart';

/// The search field's reading of what is typed (#3882): the text stands if
/// any record type reads it, and the completions are every type's.
class GlobalSearchTextReader implements QueryTextReader {
  GlobalSearchTextReader(this._context, {List<GlobalSearchSource>? sources})
    : _sources = sources ?? kGlobalSearchSources;

  /// The diver's units, names and labels. Its root stands for no one.
  final QueryEditorContext _context;
  final List<GlobalSearchSource> _sources;

  @override
  QueryError? check(String text) => globalSearchRefusal(
    text,
    context: ParseContext(
      prefs: _context.prefs,
      now: _context.now(),
      names: _context.names,
    ),
    sources: _sources,
  );

  @override
  List<Completion> completionsAt(String text, int caret) => poolCompletions([
    for (final source in _sources)
      query.completionsAt(text, caret, _context.copyWith(root: source.entity)),
  ]);
}

/// Each list's first offer, then each second, and so on, so a type with a few
/// fields is not crowded out by Dives. The same offer from two lists shows
/// once.
List<Completion> poolCompletions(List<List<Completion>> lists) {
  final pooled = <(String, int, int), Completion>{};
  final longest = lists.fold(0, (most, l) => l.length > most ? l.length : most);
  for (var rank = 0; rank < longest; rank++) {
    for (final list in lists) {
      if (rank >= list.length) continue;
      final c = list[rank];
      pooled.putIfAbsent((c.text, c.replaceStart, c.replaceLength), () => c);
      if (pooled.length == kMaxQueryCompletions) {
        return pooled.values.toList();
      }
    }
  }
  return pooled.values.toList();
}
