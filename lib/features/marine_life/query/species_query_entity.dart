import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_log/query/dive_aggregate_fields.dart';

/// A counted dive the species was seen on.
const _sightingDiveLink =
    'ad.id IN (SELECT s.dive_id FROM sightings s '
    'WHERE s.species_id = {r}.id)';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_species_$key',
);

/// Every field and relation a species query can name (#2365). Both species
/// pages root here (the diver's sighted species and the catalog); dives
/// reach it through `sightings.species`. Species are global (no diver
/// column), and SQL sees the stored English common name, so a built-in
/// species is found by its English or scientific name.
final speciesQueryEntity = QueryEntity(
  subject: QuerySubject.species,
  table: 'species',
  textSearchSql: const [
    "{r}.common_name LIKE ? ESCAPE '\\'",
    "{r}.scientific_name LIKE ? ESCAPE '\\'",
    "{r}.taxonomy_class LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'common_name'),
    _text('scientificName', 'scientific_name'),
    QueryField(
      key: 'category',
      type: FieldType.enumName,
      sql: '{r}.category',
      emptySql: "({r}.category IS NULL OR TRIM({r}.category) = '')",
      labelKey: 'query_species_category',
      enumValues: [for (final c in SpeciesCategory.values) c.name],
    ),
    _text('taxonomyClass', 'taxonomy_class'),
    _text('description', 'description'),
    const QueryField(
      key: 'builtIn',
      type: FieldType.bool,
      sql: '{r}.is_built_in',
      emptySql: '0',
      labelKey: 'query_species_builtIn',
    ),
    diveCountField('species', _sightingDiveLink, tables: const ['sightings']),
    diveDateField(
      'species',
      'firstSeen',
      _sightingDiveLink,
      first: true,
      tables: const ['sightings'],
    ),
    diveDateField(
      'species',
      'lastSeen',
      _sightingDiveLink,
      tables: const ['sightings'],
    ),
  ],
  relations: const [
    QueryRelation(
      key: 'sightings',
      target: QuerySubject.sightings,
      shape: RelationShape.child,
      joinSql: '{to}.species_id = {from}.id',
      isMany: true,
      labelKey: 'query_species_sightings',
    ),
    // The curated "expected at this site" list (site_species), not where
    // the diver saw it; that is `dives.site`.
    QueryRelation(
      key: 'expectedSites',
      target: QuerySubject.sites,
      shape: RelationShape.junction,
      joinSql:
          '{to}.id IN (SELECT j.site_id FROM site_species j '
          'WHERE j.species_id = {from}.id)',
      isMany: true,
      labelKey: 'query_species_expectedSites',
      tables: ['site_species'],
    ),
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.custom,
      joinSql:
          '{to}.id IN (SELECT s.dive_id FROM sightings s '
          'WHERE s.species_id = {from}.id)',
      isMany: true,
      labelKey: 'query_species_dives',
      tables: ['sightings'],
    ),
  ],
);
