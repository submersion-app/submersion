import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// `(dive_id, entity_id)` rows for [kind]. Each fragment is a complete
/// SELECT so it can be embedded as `JOIN (...) alias`.
///
/// Column kinds (site, trip, center, course) read the link straight off
/// `dives`; junction kinds read their many-to-many table.
// stats-scope-exempt: a bare membership fragment carries no aggregate; the
// edge and node builders that embed it apply DiveStatsScope on `dives d`.
String membershipSql(ConnectionKind kind) => switch (kind) {
  ConnectionKind.buddy =>
    'SELECT dive_id, buddy_id AS entity_id FROM dive_buddies',
  ConnectionKind.site =>
    'SELECT id AS dive_id, site_id AS entity_id FROM dives '
        'WHERE site_id IS NOT NULL',
  ConnectionKind.trip =>
    'SELECT id AS dive_id, trip_id AS entity_id FROM dives '
        'WHERE trip_id IS NOT NULL',
  ConnectionKind.diveCenter =>
    'SELECT id AS dive_id, dive_center_id AS entity_id FROM dives '
        'WHERE dive_center_id IS NOT NULL',
  ConnectionKind.equipment =>
    'SELECT dive_id, equipment_id AS entity_id FROM dive_equipment',
  ConnectionKind.species =>
    'SELECT dive_id, species_id AS entity_id FROM sightings',
  ConnectionKind.tag => 'SELECT dive_id, tag_id AS entity_id FROM dive_tags',
  ConnectionKind.diveType =>
    'SELECT dive_id, dive_type_id AS entity_id FROM dive_dive_types',
  ConnectionKind.diveComputer =>
    'SELECT dive_id, computer_id AS entity_id FROM dive_data_sources',
  ConnectionKind.course =>
    'SELECT id AS dive_id, course_id AS entity_id FROM dives '
        'WHERE course_id IS NOT NULL',
};
