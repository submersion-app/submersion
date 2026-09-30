import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/entity_resolver.dart';
import 'package:submersion/features/explore/domain/explore_clause_lowering.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/explore_mention_lowering.dart';
import 'package:submersion/features/explore/domain/explore_subject_fields.dart';
import 'package:submersion/features/explore/domain/explore_subject_lowering.dart';
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
  ) => query.subject == ParsedSubject.dives
      ? _dives(query, ctx)
      : _subject(query, ctx);

  /// The registry fields computed over all of a row's dives.
  static const _aggregates = {
    'diveCount',
    'lastDived',
    'firstSeen',
    'lastSeen',
  };

  static QueryNode? _and(List<QueryNode> nodes) => switch (nodes) {
    [] => null,
    [final only] => only,
    _ => AndNode(nodes),
  };

  /// Every mention resolved against the diver's names: the placed ones as
  /// (index, mention, entry), the rest added to [unresolved].
  static List<(int, QueryMention, NameEntry)> _resolve(
    ParsedQuery query,
    ExploreCompilerContext ctx,
    List<UnresolvedMention> unresolved,
  ) {
    final out = <(int, QueryMention, NameEntry)>[];
    for (var i = 0; i < query.mentions.length; i++) {
      final m = query.mentions[i];
      switch (resolveMention(m, ctx.names)) {
        case Resolved(:final entry):
          out.add((i, m, entry));
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
    return out;
  }

  static ExploreCompilation _dives(
    ParsedQuery query,
    ExploreCompilerContext ctx,
  ) {
    final chips = <QueryChip>[];
    final unresolved = <UnresolvedMention>[];
    final unplaced = <UnplacedItem>[];
    final nodes = <QueryNode>[];

    final trends = <ChartKind>[];
    for (var i = 0; i < query.clauses.length; i++) {
      final c = query.clauses[i];
      final r = lowerClause(c, exploreField(c.field), ctx.units, now: ctx.now);
      if (r.error != null) {
        unplaced.add(UnplacedItem(c.text, reason: r.error));
        continue;
      }
      nodes.addAll(r.nodes);
      chips.add(QueryChip(ref: ChipRef.clause, index: i, payload: r.chip!));
      if (r.chip!.field.trend case final trend?) trends.add(trend);
    }

    final resolved = <NameEntry>[];
    final entityIds = <MentionKind, Set<String>>{};
    for (final (i, m, entry) in _resolve(query, ctx, unresolved)) {
      resolved.add(entry);
      chips.add(
        QueryChip(
          ref: ChipRef.mention,
          index: i,
          payload: MentionChip(kind: m.kind, entry: entry),
        ),
      );
      entityIds.putIfAbsent(m.kind, () => {}).addAll(entry.ids);
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
      query: _and(nodes),
      chips: chips,
      unresolved: unresolved,
      unplaced: unplaced,
      charts: selectCharts(
        trends: trends,
        resolvedEntityCounts: {
          for (final e in entityIds.entries) e.key: e.value.length,
        },
      ),
    );
  }

  /// A sentence about another subject (phase 3). Its own fields, own-kind
  /// mentions and (for trips) its period lower onto the subject's rows;
  /// every other part is about its dives and lowers into [diveScope],
  /// reached through the subject's counted dives. A count or a first or
  /// last date cannot be said of a scope yet, so with one it is unplaced
  /// rather than taken over all time.
  static ExploreCompilation _subject(
    ParsedQuery query,
    ExploreCompilerContext ctx,
  ) {
    final subject = query.subject;
    final unresolved = <UnresolvedMention>[];
    final unplaced = <UnplacedItem>[];
    final chips = <QueryChip>[];
    final own = <QueryNode>[];
    final viaDives = <QueryNode>[];

    final resolved = _resolve(query, ctx, unresolved);
    final ownEntries = [
      for (final (_, _, e) in resolved)
        if (ownsTarget(subject, e.target)) e,
    ];
    final diveEntries = [
      for (final (_, _, e) in resolved)
        if (!ownsTarget(subject, e.target)) e,
    ];

    DateRange? range;
    if (query.time != null) {
      range = parseDateText(query.time!.text, now: ctx.now);
      if (range == null) {
        unplaced.add(UnplacedItem(query.time!.text, reason: 'unknownTime'));
      }
    }
    final timeViaDives = range != null && subject != ParsedSubject.trips;

    final clauses = <(int, bool, LoweredClause, QueryClause)>[];
    for (var i = 0; i < query.clauses.length; i++) {
      final c = query.clauses[i];
      final hit = exploreFieldFor(subject, c.field);
      if (hit == null) {
        unplaced.add(UnplacedItem(c.text, reason: 'unknownField'));
        continue;
      }
      final r = lowerClause(c, hit.field, ctx.units, now: ctx.now);
      if (r.error != null) {
        unplaced.add(UnplacedItem(c.text, reason: r.error));
        continue;
      }
      clauses.add((i, hit.viaDives, r, c));
    }
    final hasDivePart =
        diveEntries.isNotEmpty || timeViaDives || clauses.any((c) => c.$2);

    for (final (i, isViaDives, r, c) in clauses) {
      // A count or a first or last date is over all the row's dives, so
      // with a dive part it would answer another question than the
      // sentence asked.
      if (_aggregates.contains(r.chip!.field.name) && hasDivePart) {
        unplaced.add(UnplacedItem(c.text, reason: 'aggregateWithScope'));
        continue;
      }
      (isViaDives ? viaDives : own).addAll(r.nodes);
      chips.add(
        QueryChip(
          ref: ChipRef.clause,
          index: i,
          payload: r.chip!,
          viaDives: isViaDives,
        ),
      );
    }

    own.addAll(lowerOwnMentions(subject, ownEntries, ctx.names));
    viaDives.addAll(lowerMentions(diveEntries, ctx.names));
    for (final (i, m, e) in resolved) {
      chips.add(
        QueryChip(
          ref: ChipRef.mention,
          index: i,
          payload: MentionChip(kind: m.kind, entry: e),
          viaDives: !ownsTarget(subject, e.target),
        ),
      );
    }

    if (range != null) {
      if (timeViaDives) {
        viaDives.addAll(lowerTime(range.start, range.end));
      } else {
        own.addAll(lowerTripTime(range.start, range.end));
      }
      chips.add(
        QueryChip(
          ref: ChipRef.time,
          index: 0,
          payload: TimeChip(start: range.start, end: range.end),
          viaDives: timeViaDives,
        ),
      );
    }

    for (final w in query.unplaced) {
      unplaced.add(UnplacedItem(w));
    }
    if (viaDives.isNotEmpty) own.add(countedDives(viaDives));

    return ExploreCompilation(
      subject: subject,
      query: _and(own),
      diveScope: _and(viaDives),
      chips: chips,
      unresolved: unresolved,
      unplaced: unplaced,
      charts: const [ChartRequest(ChartKind.subjectCounts)],
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
