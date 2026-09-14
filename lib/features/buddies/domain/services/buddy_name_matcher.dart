import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';

/// The result of matching one legacy name.
sealed class NameMatch {
  const NameMatch();
}

/// One or more buddies have this exact name; [candidate] is the best ranked.
final class ExactMatch extends NameMatch {
  const ExactMatch(this.candidate, {required this.tieCount});

  final MatchCandidate candidate;
  final int tieCount;
}

/// No buddy has this name. [suggestion] is set only when exactly one
/// distinct name starts with it as a whole word.
final class NoMatch extends NameMatch {
  const NoMatch({this.suggestion});

  final MatchCandidate? suggestion;
}

/// Matches legacy names against a diver's buddies (#1831).
///
/// Namesakes rank the diver's own record first, then the most linked dives,
/// then the oldest record, then the id, so the pick is deterministic.
class BuddyNameMatcher {
  BuddyNameMatcher(List<MatchCandidate> candidates, {required this.diverId})
    : candidates = List.unmodifiable(candidates) {
    final grouped = <String, List<MatchCandidate>>{};
    for (final candidate in candidates) {
      grouped
          .putIfAbsent(legacyNameKey(candidate.name), () => [])
          .add(candidate);
    }
    _byKey = {
      for (final entry in grouped.entries)
        entry.key: List<MatchCandidate>.unmodifiable(
          <MatchCandidate>[...entry.value]..sort(_rank),
        ),
    };
  }

  final String diverId;
  final List<MatchCandidate> candidates;
  late final Map<String, List<MatchCandidate>> _byKey;

  NameMatch match(String name) {
    final key = legacyNameKey(name);
    if (key.isEmpty) return const NoMatch();
    final exact = _byKey[key];
    if (exact != null) {
      return ExactMatch(exact.first, tieCount: exact.length);
    }
    final prefix = '$key ';
    final hits = [
      for (final entry in _byKey.entries)
        if (entry.key.startsWith(prefix)) entry.value.first,
    ];
    return NoMatch(suggestion: hits.length == 1 ? hits.single : null);
  }

  int _rank(MatchCandidate a, MatchCandidate b) {
    final own = _ownRank(a).compareTo(_ownRank(b));
    if (own != 0) return own;
    final dives = b.diveCount.compareTo(a.diveCount);
    if (dives != 0) return dives;
    final age = a.createdAt.compareTo(b.createdAt);
    if (age != 0) return age;
    return a.id.compareTo(b.id);
  }

  int _ownRank(MatchCandidate candidate) =>
      candidate.diverId == diverId ? 0 : 1;
}
