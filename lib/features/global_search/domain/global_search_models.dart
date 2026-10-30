import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_node.dart';

/// Every kind of record global search finds (#3882), in the order the
/// results show them.
enum GlobalSearchKind {
  dives,
  sites,
  trips,
  equipment,
  equipmentSets,
  buddies,
  diveCenters,
  certifications,
  courses,
  species,
  documents,
  divePlans,
  gpsTracks,
  underwaterRoutes,
}

/// One matching record: only what its row shows, so a keystroke never
/// hydrates a dive's profile or a document's pages.
@immutable
class GlobalSearchHit {
  const GlobalSearchHit({
    required this.kind,
    required this.id,
    this.title,
    this.details = const [],
    this.date,
    this.depthMeters,
    this.number,
  });

  final GlobalSearchKind kind;
  final String id;

  /// Null when the record has no name of its own, such as a dive with no
  /// site or an unnamed track; its row then leads with [date].
  final String? title;

  /// The row's supporting text, each already trimmed and non-empty.
  final List<String> details;
  final DateTime? date;
  final double? depthMeters;

  /// The dive number.
  final int? number;
}

/// One record type's matches.
@immutable
class GlobalSearchSection {
  const GlobalSearchSection({
    required this.kind,
    required this.total,
    required this.hits,
    required this.query,
  });

  final GlobalSearchKind kind;

  /// Every match, which [hits] may only preview.
  final int total;
  final List<GlobalSearchHit> hits;

  /// The query this section ran, which See all hands to its list.
  final QueryNode query;
}
