import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// Minimal in PR 1 (reached through `buddies.certifications`); PR 4 of #2365
/// adds the list entry point.
const certificationQueryEntity = QueryEntity(
  subject: QuerySubject.certifications,
  table: 'certifications',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_certifications_name',
    ),
    QueryField(
      key: 'agency',
      type: FieldType.text,
      sql: '{r}.agency',
      emptySql: "({r}.agency IS NULL OR TRIM({r}.agency) = '')",
      labelKey: 'query_certifications_agency',
    ),
    QueryField(
      key: 'level',
      type: FieldType.text,
      sql: '{r}.level',
      emptySql: "({r}.level IS NULL OR TRIM({r}.level) = '')",
      labelKey: 'query_certifications_level',
    ),
    QueryField(
      key: 'cardNumber',
      type: FieldType.text,
      sql: '{r}.card_number',
      emptySql: "({r}.card_number IS NULL OR TRIM({r}.card_number) = '')",
      labelKey: 'query_certifications_cardNumber',
    ),
    QueryField(
      key: 'instructorName',
      type: FieldType.text,
      sql: '{r}.instructor_name',
      emptySql:
          "({r}.instructor_name IS NULL OR TRIM({r}.instructor_name) = '')",
      labelKey: 'query_certifications_instructorName',
    ),
    QueryField(
      key: 'issueDate',
      type: FieldType.date,
      dateFrame: DateFrame.localInstant,
      sql: '{r}.issue_date',
      emptySql: '{r}.issue_date IS NULL',
      labelKey: 'query_certifications_issueDate',
    ),
    QueryField(
      key: 'expiryDate',
      type: FieldType.date,
      dateFrame: DateFrame.localInstant,
      sql: '{r}.expiry_date',
      emptySql: '{r}.expiry_date IS NULL',
      labelKey: 'query_certifications_expiryDate',
    ),
  ],
);
