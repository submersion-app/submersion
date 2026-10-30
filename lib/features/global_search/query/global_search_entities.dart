import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';

/// Text search over [column] on the row, folded as the query compiler
/// expects (#3032).
String _like(String column) => "unicode_lower({r}.$column) LIKE ? ESCAPE '\\'";

/// Records with no list query of their own (#3882). They are roots global
/// search compiles directly, never registered: with no fields and no
/// relations, field syntax is refused and plain words are all they read.
final equipmentSetSearchEntity = QueryEntity(
  subject: QuerySubject.equipmentSets,
  table: 'equipment_sets',
  diverScopeColumn: 'diver_id',
  textSearchSql: [_like('name'), _like('description')],
);

/// A document's owner, as a name of [table] linked through [column].
String _ownerName(String table, String column) =>
    'EXISTS (SELECT 1 FROM $table towner WHERE towner.id = {r}.$column '
    "AND unicode_lower(towner.name) LIKE ? ESCAPE '\\')";

/// What the Documents page's search reads, the owner and tags included, plus
/// the notes: this section has no list to disagree with, and a note is shown
/// on the document it belongs to.
final documentSearchEntity = QueryEntity(
  subject: QuerySubject.documents,
  table: 'documents',
  diverScopeColumn: 'diver_id',
  textSearchSql: [
    _like('title'),
    _like('issuer'),
    _like('reference_number'),
    _like('notes'),
    _ownerName('dive_sites', 'site_id'),
    _ownerName('trips', 'trip_id'),
    _ownerName('equipment', 'equipment_id'),
    _ownerName('courses', 'course_id'),
    _ownerName('certifications', 'certification_id'),
    _ownerName('buddies', 'buddy_id'),
    _ownerName('dive_centers', 'dive_center_id'),
    'EXISTS (SELECT 1 FROM dives tdive LEFT JOIN dive_sites tsite '
        'ON tsite.id = tdive.site_id WHERE tdive.id = {r}.dive_id '
        "AND (unicode_lower(tdive.name) LIKE ? ESCAPE '\\' "
        "OR unicode_lower(tsite.name) LIKE ? ESCAPE '\\'))",
    'EXISTS (SELECT 1 FROM document_tags tdt JOIN tags tt '
        'ON tt.id = tdt.tag_id WHERE tdt.document_id = {r}.id '
        "AND unicode_lower(tt.name) LIKE ? ESCAPE '\\')",
  ],
  textSearchTables: const [
    'dive_sites',
    'trips',
    'equipment',
    'courses',
    'certifications',
    'buddies',
    'dive_centers',
    'dives',
    'document_tags',
    'tags',
  ],
);

final divePlanSearchEntity = QueryEntity(
  subject: QuerySubject.divePlans,
  table: 'dive_plans',
  diverScopeColumn: 'diver_id',
  textSearchSql: [_like('name'), _like('notes')],
);

final gpsTrackSearchEntity = QueryEntity(
  subject: QuerySubject.gpsTracks,
  table: 'gps_tracks',
  textSearchSql: [_like('name'), _like('source_ref'), _like('device_name')],
);

final navTrackSearchEntity = QueryEntity(
  subject: QuerySubject.navTracks,
  table: 'nav_tracks',
  diverScopeColumn: 'diver_id',
  textSearchSql: [_like('name'), _like('source_ref'), _like('device_name')],
);
