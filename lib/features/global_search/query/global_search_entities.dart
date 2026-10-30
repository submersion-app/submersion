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

final documentSearchEntity = QueryEntity(
  subject: QuerySubject.documents,
  table: 'documents',
  diverScopeColumn: 'diver_id',
  textSearchSql: [
    _like('title'),
    _like('issuer'),
    _like('reference_number'),
    _like('notes'),
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
