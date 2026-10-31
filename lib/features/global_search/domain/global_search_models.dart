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

/// One record type's matches.
@immutable
class GlobalSearchSection {
  const GlobalSearchSection({
    required this.kind,
    required this.total,
    required this.ids,
    required this.query,
    required this.hasList,
  });

  final GlobalSearchKind kind;

  /// Every match, which [ids] may only preview.
  final int total;

  /// The records to show, in their list's order.
  final List<String> ids;

  /// The query this section ran, which See all hands to its list.
  final QueryNode query;

  /// Whether See all opens a list. Without one, [ids] holds every match
  /// and the section expands in place.
  final bool hasList;
}
