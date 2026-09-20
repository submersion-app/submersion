import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

sealed class Resolution {
  const Resolution();
}

class Resolved extends Resolution {
  final NameEntry entry;
  final double score;
  const Resolved(this.entry, this.score);
}

class Ambiguous extends Resolution {
  final List<NameEntry> candidates;
  const Ambiguous(this.candidates);
}

class Unresolved extends Resolution {
  const Unresolved();
}

/// Resolves one mention against the diver's own names by Dice similarity.
///
/// Walks the kind's rank groups in order and stops at the first group with a
/// score at or above [threshold]. A top pair within [tieGap] that maps to
/// different identities is [Ambiguous]; nothing at threshold is [Unresolved].
/// A `place` mention falls through to site names; a `site` mention falls
/// through to places, so "Bonaire" and "Salt Pier" both work under either.
Resolution resolveMention(
  QueryMention mention,
  NameIndex index, {
  double threshold = 0.75,
  double tieGap = 0.05,
}) {
  final query = normalize(mention.text);
  if (query.isEmpty) return const Unresolved();

  final groups = <List<NameEntry>>[];
  void addGroups(MentionKind kind) {
    final byRank = <int, List<NameEntry>>{};
    for (final e in index.forKind(kind)) {
      byRank.putIfAbsent(e.rank, () => []).add(e);
    }
    final ranks = byRank.keys.toList()..sort();
    for (final r in ranks) {
      groups.add(byRank[r]!);
    }
  }

  addGroups(mention.kind);
  if (mention.kind == MentionKind.place) addGroups(MentionKind.site);
  if (mention.kind == MentionKind.site) addGroups(MentionKind.place);

  for (final group in groups) {
    final scored = <(NameEntry, double)>[];
    for (final e in group) {
      final s = diceCoefficient(query, normalize(e.label));
      if (s >= threshold) scored.add((e, s));
    }
    if (scored.isEmpty) continue;
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    // Collapse labels that lower to the same thing (a species by three names).
    final seen = <String>{};
    final distinct = <(NameEntry, double)>[];
    for (final s in scored) {
      if (seen.add(s.$1.identity)) distinct.add(s);
    }
    if (distinct.length >= 2 && distinct[0].$2 - distinct[1].$2 <= tieGap) {
      return Ambiguous(distinct.take(5).map((s) => s.$1).toList());
    }
    return Resolved(distinct.first.$1, distinct.first.$2);
  }
  return const Unresolved();
}
