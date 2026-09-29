import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/entity_resolver.dart';
import 'package:submersion/features/explore/domain/explore_clause_lowering.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/explore_mention_lowering.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

class ExploreCompilerContext {
  final UnitPrefs units;
  final NameIndex names;
  final DateTime now;
  const ExploreCompilerContext({
    required this.units,
    required this.names,
    required this.now,
  });
}

/// Deterministic lowering of a [ParsedQuery] to one query over the dive
/// registry (#2365 PR 5).
///
/// The model chose the words; everything about units, names, ids and ranges
/// is decided here, so a canned JSON payload fully specifies the outcome.
abstract final class ExploreCompiler {
  static ExploreCompilation compile(
    ParsedQuery query,
    ExploreCompilerContext ctx,
  ) {
    if (query.subject != ParsedSubject.dives) {
      return ExploreCompilation(
        query: null,
        chips: const [],
        unresolved: const [],
        unplaced: [
          UnplacedItem(query.subject.name, reason: 'subjectNotSupported'),
          for (final w in query.unplaced) UnplacedItem(w),
        ],
        charts: const [],
      );
    }

    final chips = <QueryChip>[];
    final unresolved = <UnresolvedMention>[];
    final unplaced = <UnplacedItem>[];
    final nodes = <QueryNode>[];

    final numericFields = <String>[];
    for (var i = 0; i < query.clauses.length; i++) {
      final c = query.clauses[i];
      final r = lowerClause(c, exploreField(c.field), ctx.units);
      if (r.error != null) {
        unplaced.add(UnplacedItem(c.text, reason: r.error));
        continue;
      }
      nodes.addAll(r.nodes);
      chips.add(QueryChip(ref: ChipRef.clause, index: i, payload: r.chip!));
      if (r.chip!.dimension != FieldDimension.none) {
        numericFields.add(r.chip!.field.name);
      }
    }

    final resolved = <NameEntry>[];
    final entityIds = <MentionKind, Set<String>>{};
    for (var i = 0; i < query.mentions.length; i++) {
      final m = query.mentions[i];
      final res = resolveMention(m, ctx.names);
      switch (res) {
        case Resolved(:final entry):
          resolved.add(entry);
          chips.add(
            QueryChip(
              ref: ChipRef.mention,
              index: i,
              payload: MentionChip(kind: m.kind, entry: entry),
            ),
          );
          entityIds.putIfAbsent(m.kind, () => {}).addAll(entry.ids);
        case Ambiguous(:final candidates):
          unresolved.add(
            UnresolvedMention(index: i, mention: m, candidates: candidates),
          );
        case Unresolved():
          unresolved.add(
            UnresolvedMention(
              index: i,
              mention: m,
              candidates: _nearest(m, ctx.names),
            ),
          );
      }
    }
    nodes.addAll(lowerMentions(resolved, ctx.names));

    if (query.time != null) {
      final range = parseDateText(query.time!.text, now: ctx.now);
      if (range == null) {
        unplaced.add(UnplacedItem(query.time!.text, reason: 'unknownTime'));
      } else {
        nodes.addAll(lowerTime(range.start, range.end));
        chips.add(
          QueryChip(
            ref: ChipRef.time,
            index: 0,
            payload: TimeChip(start: range.start, end: range.end),
          ),
        );
      }
    }

    for (final w in query.unplaced) {
      unplaced.add(UnplacedItem(w));
    }

    return ExploreCompilation(
      query: switch (nodes) {
        [] => null,
        [final only] => only,
        _ => AndNode(nodes),
      },
      chips: chips,
      unresolved: unresolved,
      unplaced: unplaced,
      charts: selectCharts(
        numericFields: numericFields,
        resolvedEntityCounts: {
          for (final e in entityIds.entries) e.key: e.value.length,
        },
      ),
    );
  }

  /// Up to five labels above a loose similarity floor, offered as candidates
  /// for a mention the strict resolver could not place. Searches the same
  /// kinds the resolver does, so a misspelt place can suggest a site.
  static List<NameEntry> _nearest(QueryMention m, NameIndex names) {
    final q = normalize(m.text);
    final scored = <(NameEntry, double)>[];
    for (final e in [
      for (final k in mentionSearchKinds(m.kind)) ...entriesForKind(names, k),
    ]) {
      final s = diceCoefficient(q, normalize(e.label));
      if (s > 0.3) scored.add((e, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final seen = <String>{};
    return [
      for (final s in scored)
        if (seen.add(s.$1.identity)) s.$1,
    ].take(5).toList();
  }
}
