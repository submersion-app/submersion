import 'package:meta/meta.dart';

import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/features/dive_log/query/dive_number_query.dart';
import 'package:submersion/features/global_search/data/global_search_sources.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// One source that can read the typed text.
@immutable
class GlobalSearchRun {
  const GlobalSearchRun({
    required this.source,
    required this.query,
    required this.compiled,
  });

  final GlobalSearchSource source;
  final QueryNode query;
  final CompiledQuery compiled;

  /// Every table this run reads: a write to any of them changes its results.
  Set<String> get tables => {...compiled.tablesTouched, ...source.tables};
}

/// What the typed text asks of each source.
@immutable
class GlobalSearchPlan {
  const GlobalSearchPlan({required this.runs, this.refusal});

  final List<GlobalSearchRun> runs;

  /// Why the text was refused, when every source refused it. A source
  /// refusing while another reads it is not an error: `depth > 30m` means
  /// nothing for a buddy.
  final QueryError? refusal;
}

/// Parses [text] once per source: each reads it against its own fields.
GlobalSearchPlan planGlobalSearch(
  String text, {
  required ParseContext context,
  String? diverId,
  List<GlobalSearchSource>? sources,
}) {
  final runs = <GlobalSearchRun>[];
  QueryError? refusal;
  for (final source in sources ?? kGlobalSearchSources) {
    final read = _read(source, text, context);
    refusal = _moreHelpful(refusal, read.refusal);
    if (read.query case final query?) {
      runs.add(
        GlobalSearchRun(
          source: source,
          query: query,
          compiled: compileQuery(
            query,
            source.entity,
            appQueryRegistry,
            diverId: diverId,
          ),
        ),
      );
    }
  }
  return GlobalSearchPlan(runs: runs, refusal: runs.isEmpty ? refusal : null);
}

/// Why no source reads [text], or null when one does: [planGlobalSearch]'s
/// verdict with nothing compiled, for the field to ask on every keystroke.
QueryError? globalSearchRefusal(
  String text, {
  required ParseContext context,
  List<GlobalSearchSource>? sources,
}) {
  QueryError? refusal;
  for (final source in sources ?? kGlobalSearchSources) {
    final read = _read(source, text, context);
    if (read.query != null) return null;
    refusal = _moreHelpful(refusal, read.refusal);
  }
  return refusal;
}

/// What [source] makes of [text]: a query, why it refuses, or neither for
/// nothing to read.
({QueryNode? query, QueryError? refusal}) _read(
  GlobalSearchSource source,
  String text,
  ParseContext context,
) {
  switch (QueryParser(appQueryRegistry, source.entity, context).parse(text)) {
    case ParseFailure(:final error):
      return (query: null, refusal: error);
    case ParseOk(node: null):
      return (query: null, refusal: null);
    case ParseOk(:final node?):
      final query = _widened(source, node);
      final errors = validateQuery(query, source.entity, appQueryRegistry);
      return errors.isEmpty
          ? (query: query, refusal: null)
          : (query: null, refusal: errors.first);
  }
}

/// The refusal to show: the first, unless a later source can suggest a fix
/// and it cannot. A typo in `expirs < 2027` means nothing to Dives, but
/// Documents knows what was meant.
QueryError? _moreHelpful(QueryError? kept, QueryError? next) {
  if (kept == null) return next;
  if (next == null || kept.suggestions.isNotEmpty) return kept;
  return next.suggestions.isNotEmpty ? next : kept;
}

/// A bare number also finds the dive with that number (#3455).
QueryNode _widened(GlobalSearchSource source, QueryNode node) {
  if (source.kind != GlobalSearchKind.dives) return node;
  final number = bareDiveNumber(node);
  return number == null ? node : OrNode([node, diveNumberQuery(number)]);
}
