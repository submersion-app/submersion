import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// Reached through `dives.sightings.species`; PR 4 of #2365 adds the list
/// entry point.
const speciesQueryEntity = QueryEntity(
  subject: QuerySubject.species,
  table: 'species',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.common_name',
      emptySql: "({r}.common_name IS NULL OR TRIM({r}.common_name) = '')",
      labelKey: 'query_species_name',
    ),
    QueryField(
      key: 'scientificName',
      type: FieldType.text,
      sql: '{r}.scientific_name',
      emptySql:
          "({r}.scientific_name IS NULL OR TRIM({r}.scientific_name) = '')",
      labelKey: 'query_species_scientificName',
    ),
    QueryField(
      key: 'category',
      type: FieldType.text,
      sql: '{r}.category',
      emptySql: "({r}.category IS NULL OR TRIM({r}.category) = '')",
      labelKey: 'query_species_category',
    ),
  ],
);
