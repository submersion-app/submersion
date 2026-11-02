import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

/// Text search over [column] on the row, folded as the query compiler
/// expects (#3032).
String _like(String column) => "unicode_lower({r}.$column) LIKE ? ESCAPE '\\'";

/// A document's owner, as a name of [table] linked through [column].
String _ownerName(String table, String column) =>
    'EXISTS (SELECT 1 FROM $table towner WHERE towner.id = {r}.$column '
    "AND unicode_lower(towner.name) LIKE ? ESCAPE '\\')";

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_documents_$key',
);

QueryField _date(String key, String column, {required String alias}) =>
    QueryField(
      key: key,
      aliases: [alias],
      type: FieldType.date,
      dateFrame: DateFrame.localInstant,
      sql: '{r}.$column',
      emptySql: '{r}.$column IS NULL',
      labelKey: 'query_documents_$key',
    );

/// The record a document is filed under, through its [column].
QueryRelation _owner(String key, QuerySubject target, String column) =>
    QueryRelation(
      key: key,
      target: target,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.$column',
      isMany: false,
      labelKey: 'query_documents_$key',
    );

/// Every field and relation a document query can name (#3882). A word reads
/// what the Documents page's search reads, the owner and tags included, plus
/// the notes: global search has no list to disagree with, and a note is shown
/// on the document it belongs to.
final documentQueryEntity = QueryEntity(
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
    // A certification with no custom name is titled by its agency and
    // level (#3366), so those find it too.
    'EXISTS (SELECT 1 FROM certifications towner '
        'WHERE towner.id = {r}.certification_id '
        "AND (unicode_lower(towner.name) LIKE ? ESCAPE '\\' "
        "OR unicode_lower(towner.agency) LIKE ? ESCAPE '\\' "
        "OR unicode_lower(towner.level) LIKE ? ESCAPE '\\'))",
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
  fields: [
    _text('title', 'title'),
    QueryField(
      key: 'type',
      type: FieldType.enumName,
      sql: '{r}.type',
      emptySql: '0',
      labelKey: 'query_documents_type',
      enumValues: [for (final t in DocumentType.values) t.storage],
    ),
    _text('issuer', 'issuer'),
    const QueryField(
      key: 'referenceNumber',
      aliases: ['reference'],
      type: FieldType.text,
      sql: '{r}.reference_number',
      emptySql:
          "({r}.reference_number IS NULL OR TRIM({r}.reference_number) = '')",
      labelKey: 'query_documents_referenceNumber',
    ),
    _date('issueDate', 'issue_date', alias: 'issued'),
    _date('expiryDate', 'expiry_date', alias: 'expires'),
    const QueryField(
      key: 'primary',
      type: FieldType.bool,
      sql: '{r}.is_primary',
      emptySql: '0',
      labelKey: 'query_documents_primary',
    ),
    _text('notes', 'notes'),
  ],
  relations: [
    const QueryRelation(
      key: 'tags',
      target: QuerySubject.tags,
      shape: RelationShape.junction,
      joinSql:
          '{to}.id IN (SELECT j.tag_id FROM document_tags j '
          'WHERE j.document_id = {from}.id)',
      isMany: true,
      labelKey: 'query_documents_tags',
      tables: ['document_tags'],
    ),
    _owner('dive', QuerySubject.dives, 'dive_id'),
    _owner('site', QuerySubject.sites, 'site_id'),
    _owner('trip', QuerySubject.trips, 'trip_id'),
    _owner('equipment', QuerySubject.equipment, 'equipment_id'),
    _owner('course', QuerySubject.courses, 'course_id'),
    _owner('certification', QuerySubject.certifications, 'certification_id'),
    _owner('buddy', QuerySubject.buddies, 'buddy_id'),
    _owner('center', QuerySubject.centers, 'dive_center_id'),
  ],
);
