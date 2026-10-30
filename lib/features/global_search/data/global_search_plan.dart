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

  /// Why the first source refused the text, when every source did. A
  /// source refusing while another reads it is not an error: `depth > 30m`
  /// means nothing for a buddy.
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
  QueryError? firstRefusal;
  for (final source in sources ?? kGlobalSearchSources) {
    final parsed = QueryParser(
      appQueryRegistry,
      source.entity,
      context,
    ).parse(text);
    switch (parsed) {
      case ParseFailure(:final error):
        firstRefusal ??= error;
      case ParseOk(node: null):
        break;
      case ParseOk(:final node?):
        final query = _widened(source, node);
        final errors = validateQuery(query, source.entity, appQueryRegistry);
        if (errors.isNotEmpty) {
          firstRefusal ??= errors.first;
          continue;
        }
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
  return GlobalSearchPlan(
    runs: runs,
    refusal: runs.isEmpty ? firstRefusal : null,
  );
}

/// A bare number also finds the dive with that number (#3455).
QueryNode _widened(GlobalSearchSource source, QueryNode node) {
  if (source.kind != GlobalSearchKind.dives) return node;
  final number = bareDiveNumber(node);
  return number == null ? node : OrNode([node, diveNumberQuery(number)]);
}
