import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
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

/// The index subject and targets a mention kind is looked up under.
({QuerySubject subject, Set<NameTarget> targets}) mentionScope(
  MentionKind kind,
) => switch (kind) {
  MentionKind.site => (
    subject: QuerySubject.sites,
    targets: {NameTarget.siteId},
  ),
  MentionKind.place => (
    subject: QuerySubject.sites,
    targets: {NameTarget.sitePlace},
  ),
  MentionKind.species => (
    subject: QuerySubject.species,
    targets: {NameTarget.speciesId},
  ),
  MentionKind.gear => (
    subject: QuerySubject.equipment,
    targets: {NameTarget.equipmentId, NameTarget.attrChoice},
  ),
  MentionKind.buddy => (
    subject: QuerySubject.buddies,
    targets: {NameTarget.buddyId, NameTarget.legacyBuddyName},
  ),
  MentionKind.tag => (subject: QuerySubject.tags, targets: {NameTarget.tagId}),
  MentionKind.center => (
    subject: QuerySubject.centers,
    targets: {NameTarget.centerId},
  ),
  MentionKind.trip => (
    subject: QuerySubject.trips,
    targets: {NameTarget.tripId},
  ),
  MentionKind.computer => (
    subject: QuerySubject.computers,
    targets: {NameTarget.computerId},
  ),
};

/// The entries a mention of [kind] can match, in the index's order.
Iterable<NameEntry> entriesForKind(NameIndex index, MentionKind kind) {
  final scope = mentionScope(kind);
  return index
      .forSubject(scope.subject)
      .where((e) => scope.targets.contains(e.target));
}

/// The mention kind a picked entry pins as: the kind whose scope holds
/// [target]. A typed-query row target has none.
MentionKind mentionKindOf(NameTarget target) {
  for (final kind in MentionKind.values) {
    if (mentionScope(kind).targets.contains(target)) return kind;
  }
  throw ArgumentError.value(target, 'target', 'no mention kind');
}

/// The kinds a mention of [kind] is looked up under, in priority order. A
/// place falls through to sites and a site to places, so "Bonaire" and
/// "Salt Pier" both work under either.
List<MentionKind> mentionSearchKinds(MentionKind kind) => switch (kind) {
  MentionKind.place => const [MentionKind.place, MentionKind.site],
  MentionKind.site => const [MentionKind.site, MentionKind.place],
  _ => [kind],
};

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
    for (final e in entriesForKind(index, kind)) {
      byRank.putIfAbsent(e.rank, () => []).add(e);
    }
    final ranks = byRank.keys.toList()..sort();
    for (final r in ranks) {
      groups.add(byRank[r]!);
    }
  }

  mentionSearchKinds(mention.kind).forEach(addGroups);

  // A pick the diver already made wins outright. A pin whose entity no
  // longer exists falls through to the words, so a deleted buddy degrades
  // to a normal lookup instead of silently dropping the mention.
  final pinned = mention.identity;
  if (pinned != null) {
    for (final group in groups) {
      for (final e in group) {
        if (e.identity == pinned) return Resolved(e, 1.0);
      }
    }
  }

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
