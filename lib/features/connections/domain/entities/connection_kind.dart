/// The kinds of entity that can sit at either end of a connection.
///
/// Every kind is linked to dives, so any two kinds (or one kind with itself)
/// can be related by counting the dives they share.
enum ConnectionKind {
  buddy,
  site,
  trip,
  diveCenter,
  equipment,
  species,
  tag,
  diveType,
  diveComputer,
  course;

  /// Parses the enum name as written in routes and [NodeRef] wire strings.
  static ConnectionKind? fromName(String? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

  /// The nav destination whose accent colour this kind borrows for node
  /// fills and the legend. Null for tags, which carry their own colour.
  String? get accentFeatureId => switch (this) {
    ConnectionKind.buddy => 'buddies',
    ConnectionKind.site => 'sites',
    ConnectionKind.trip => 'trips',
    ConnectionKind.diveCenter => 'dive-centers',
    ConnectionKind.equipment => 'equipment',
    ConnectionKind.species => 'species',
    ConnectionKind.course => 'courses',
    ConnectionKind.diveType => 'dives',
    ConnectionKind.diveComputer => 'transfer',
    ConnectionKind.tag => null,
  };

  /// The detail route for an entity of this kind, or null when the kind has
  /// no detail page (tags, dive types and computers live in Settings).
  String? detailRoute(String id) => switch (this) {
    ConnectionKind.buddy => '/buddies/$id',
    ConnectionKind.site => '/sites/$id',
    ConnectionKind.trip => '/trips/$id',
    ConnectionKind.diveCenter => '/dive-centers/$id',
    ConnectionKind.equipment => '/equipment/$id',
    ConnectionKind.species => '/species/$id',
    ConnectionKind.course => '/courses/$id',
    ConnectionKind.tag ||
    ConnectionKind.diveType ||
    ConnectionKind.diveComputer => null,
  };
}
