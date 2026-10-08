import 'package:meta/meta.dart';

import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

/// Everything the editor widgets need that is not the tree itself (#2365):
/// the registry and the entity being queried, the diver's units, how refs
/// resolve, how things are labelled, and the clock the date grammar uses.
///
/// The feature layer builds one from providers; tests build one from the
/// fixture registry and maps.
@immutable
class QueryEditorContext {
  const QueryEditorContext({
    required this.registry,
    required this.root,
    required this.prefs,
    required this.names,
    required this.labels,
    required this.now,
  });

  final QueryRegistry registry;
  final QueryEntity root;
  final UnitPrefs prefs;
  final NameResolver names;
  final QueryLabels labels;
  final DateTime Function() now;

  /// A parser for this moment: `last 7 days` is anchored on [now] when the
  /// text is parsed, not when the editor opened.
  QueryParser get parser => QueryParser(
    registry,
    root,
    ParseContext(prefs: prefs, now: now(), names: names),
  );

  QueryPrinter get printer => QueryPrinter(registry, root, prefs);

  QueryEditorContext copyWith({
    UnitPrefs? prefs,
    NameResolver? names,
    QueryLabels? labels,
  }) => QueryEditorContext(
    registry: registry,
    root: root,
    prefs: prefs ?? this.prefs,
    names: names ?? this.names,
    labels: labels ?? this.labels,
    now: now,
  );
}
