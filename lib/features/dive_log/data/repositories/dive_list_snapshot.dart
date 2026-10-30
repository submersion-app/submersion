import 'package:flutter/foundation.dart' show listEquals;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive's id and a digest of its whole `dives` row.
typedef DiveRowDigest = ({String id, int digest});

/// A hydrated dive list and the row digests it was built from, so the next
/// refresh can hydrate only what changed (#3815).
///
/// [rows] and [dives] run in step, in list order. Digests are comparable only
/// within one database connection; after a reconnect every dive reads as
/// changed, which costs one full hydration and nothing else.
class DiveListSnapshot {
  const DiveListSnapshot._(this.rows, this.dives);

  /// A snapshot holding nothing, so that every dive is stale against it.
  const DiveListSnapshot.empty() : this._(const [], const []);

  final List<DiveRowDigest> rows;
  final List<Dive> dives;

  /// Whether [latest] is exactly what this snapshot holds, order included.
  bool isCurrentFor(List<DiveRowDigest> latest) => listEquals(rows, latest);

  /// The ids in [latest] this snapshot lacks, or holds with another digest.
  List<String> staleIdsFor(List<DiveRowDigest> latest) {
    final held = rows.toSet();
    return [
      for (final row in latest)
        if (!held.contains(row)) row.id,
    ];
  }

  /// This snapshot moved to [latest], with [hydrated] replacing its stale
  /// dives. A row with no dive was deleted after [latest] was read, and is
  /// dropped so that [rows] and [dives] stay in step.
  DiveListSnapshot advancedTo(
    List<DiveRowDigest> latest, {
    List<Dive> hydrated = const [],
  }) {
    final held = {
      for (var i = 0; i < rows.length; i++) rows[i].id: dives[i],
      for (final dive in hydrated) dive.id: dive,
    };
    final kept = latest.where((row) => held.containsKey(row.id)).toList();
    return DiveListSnapshot._(kept, [for (final row in kept) held[row.id]!]);
  }
}
