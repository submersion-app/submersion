import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// Reached through `dives.computer`.
const diveComputerQueryEntity = QueryEntity(
  subject: QuerySubject.computers,
  table: 'dive_computers',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_computers_name',
    ),
    QueryField(
      key: 'manufacturer',
      type: FieldType.text,
      sql: '{r}.manufacturer',
      emptySql: "({r}.manufacturer IS NULL OR TRIM({r}.manufacturer) = '')",
      labelKey: 'query_computers_manufacturer',
    ),
    QueryField(
      key: 'model',
      type: FieldType.text,
      sql: '{r}.model',
      emptySql: "({r}.model IS NULL OR TRIM({r}.model) = '')",
      labelKey: 'query_computers_model',
    ),
    QueryField(
      key: 'serialNumber',
      type: FieldType.text,
      sql: '{r}.serial_number',
      emptySql: "({r}.serial_number IS NULL OR TRIM({r}.serial_number) = '')",
      labelKey: 'query_computers_serialNumber',
    ),
  ],
);
