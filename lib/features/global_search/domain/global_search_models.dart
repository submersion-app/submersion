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
    this.type,
  });

  final GlobalSearchKind kind;
  final String id;

  /// Null when the record has no name of its own, such as a dive with
  /// neither a site nor a name, or an unnamed track; its row then leads with
  /// [date].
  final String? title;

  /// The row's supporting text, each already trimmed and non-empty.
  final List<String> details;
  final DateTime? date;
  final double? depthMeters;

  /// The dive number.
  final int? number;

  /// The document's stored type.
  final String? type;
}

/// One record type's matches.
@immutable
class GlobalSearchSection {
  const GlobalSearchSection({
    required this.kind,
    required this.total,
    required this.hits,
    required this.query,
    required this.hasList,
  });

  final GlobalSearchKind kind;

  /// Every match, which [hits] may only preview.
  final int total;
  final List<GlobalSearchHit> hits;

  /// The query this section ran, which See all hands to its list.
  final QueryNode query;

  /// Whether See all opens a list. Without one, [hits] holds every match
  /// and the section expands in place.
  final bool hasList;
}
