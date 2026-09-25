import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

/// A small dive-shaped registry for syntax and compiler tests: enough field
/// types and relation shapes to exercise every rule without the real one.
const fixtureDives = QueryEntity(
  subject: QuerySubject.dives,
  table: 'dives',
  diverScopeColumn: 'diver_id',
  textSearchSql: [
    "{r}.notes LIKE ? ESCAPE '\\'",
    'EXISTS (SELECT 1 FROM dive_sites ts WHERE ts.id = {r}.site_id '
        "AND ts.name LIKE ? ESCAPE '\\')",
  ],
  textSearchTables: ['dive_sites'],
  fields: [
    QueryField(
      key: 'id',
      type: FieldType.id,
      sql: '{r}.id',
      emptySql: '{r}.id IS NULL',
      labelKey: 'x',
    ),
    QueryField(
      key: 'depth',
      aliases: ['maxDepth'],
      type: FieldType.number,
      dimension: FieldDimension.depth,
      sql: '{r}.max_depth',
      emptySql: '{r}.max_depth IS NULL',
      labelKey: 'x',
      sanity: (min: 0, max: 400),
    ),
    QueryField(
      key: 'waterTemp',
      aliases: ['temp'],
      type: FieldType.number,
      dimension: FieldDimension.temperature,
      sql: '{r}.water_temp',
      emptySql: '{r}.water_temp IS NULL',
      labelKey: 'x',
      sanity: (min: -5, max: 45),
    ),
    QueryField(
      key: 'bottomTime',
      aliases: ['time'],
      type: FieldType.number,
      dimension: FieldDimension.minutes,
      sql: '({r}.bottom_time / 60)',
      emptySql: '{r}.bottom_time IS NULL',
      labelKey: 'x',
    ),
    QueryField(
      key: 'rating',
      type: FieldType.number,
      sql: '{r}.rating',
      emptySql: '{r}.rating IS NULL',
      labelKey: 'x',
      sanity: (min: 0, max: 5),
    ),
    QueryField(
      key: 'notes',
      type: FieldType.text,
      sql: '{r}.notes',
      emptySql: "({r}.notes IS NULL OR TRIM({r}.notes) = '')",
      labelKey: 'x',
    ),
    QueryField(
      key: 'favorite',
      type: FieldType.bool,
      sql: '{r}.is_favorite',
      emptySql: '0',
      labelKey: 'x',
    ),
    QueryField(
      key: 'deco',
      type: FieldType.bool,
      sql: '',
      emptySql: '0',
      labelKey: 'x',
      boolSql: (
        whenTrue: '({r}.deco_flag = 1)',
        whenFalse: '({r}.deco_flag = 0)',
      ),
    ),
    QueryField(
      key: 'waterType',
      type: FieldType.enumName,
      sql: '{r}.water_type',
      emptySql: '{r}.water_type IS NULL',
      labelKey: 'x',
      enumValues: ['salt', 'fresh', 'brackish'],
    ),
    QueryField(
      key: 'weekday',
      type: FieldType.enumName,
      sql:
          "CAST(strftime('%w', {r}.dive_date_time / 1000, 'unixepoch') "
          'AS INTEGER)',
      emptySql: '0',
      labelKey: 'x',
      enumValues: [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ],
      enumSqlValues: {
        'monday': 1,
        'tuesday': 2,
        'wednesday': 3,
        'thursday': 4,
        'friday': 5,
        'saturday': 6,
        'sunday': 0,
      },
    ),
    QueryField(
      key: 'date',
      type: FieldType.date,
      sql: '{r}.dive_date_time',
      emptySql: '{r}.dive_date_time IS NULL',
      labelKey: 'x',
    ),
  ],
  relations: [
    QueryRelation(
      key: 'site',
      target: QuerySubject.sites,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.site_id',
      isMany: false,
      labelKey: 'x',
    ),
    QueryRelation(
      key: 'weights',
      target: QuerySubject.weights,
      shape: RelationShape.child,
      joinSql: '{to}.dive_id = {from}.id',
      isMany: true,
      labelKey: 'x',
    ),
    QueryRelation(
      key: 'buddies',
      target: QuerySubject.buddies,
      shape: RelationShape.junction,
      joinSql:
          'EXISTS (SELECT 1 FROM dive_buddies j WHERE j.dive_id = {from}.id '
          'AND j.buddy_id = {to}.id)',
      isMany: true,
      labelKey: 'x',
      emptySql:
          "(({from}.buddy IS NULL OR {from}.buddy = '') AND NOT EXISTS "
          '(SELECT 1 FROM dive_buddies j WHERE j.dive_id = {from}.id))',
      tables: ['dive_buddies'],
    ),
    QueryRelation(
      key: 'gear',
      target: QuerySubject.equipment,
      shape: RelationShape.custom,
      joinSql:
          '{to}.id IN (SELECT de.equipment_id FROM dive_equipment de '
          'WHERE de.dive_id = {from}.id)',
      isMany: true,
      labelKey: 'x',
      tables: ['dive_equipment'],
    ),
  ],
);

const fixtureSites = QueryEntity(
  subject: QuerySubject.sites,
  table: 'dive_sites',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "TRIM({r}.name) = ''",
      labelKey: 'x',
    ),
    QueryField(
      key: 'country',
      type: FieldType.text,
      sql: '{r}.country',
      emptySql: '{r}.country IS NULL',
      labelKey: 'x',
    ),
  ],
);

const fixtureWeights = QueryEntity(
  subject: QuerySubject.weights,
  table: 'dive_weights',
  fields: [
    QueryField(
      key: 'amount',
      type: FieldType.number,
      dimension: FieldDimension.weight,
      sql: '{r}.amount_kg',
      emptySql: '{r}.amount_kg IS NULL',
      labelKey: 'x',
    ),
  ],
);

const fixtureBuddies = QueryEntity(
  subject: QuerySubject.buddies,
  table: 'buddies',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "TRIM({r}.name) = ''",
      labelKey: 'x',
    ),
  ],
  relations: [
    QueryRelation(
      key: 'certifications',
      target: QuerySubject.certifications,
      shape: RelationShape.child,
      joinSql: '{to}.buddy_id = {from}.id',
      isMany: true,
      labelKey: 'x',
    ),
  ],
);

const fixtureCertifications = QueryEntity(
  subject: QuerySubject.certifications,
  table: 'certifications',
  fields: [
    QueryField(
      key: 'level',
      type: FieldType.text,
      sql: '{r}.level',
      emptySql: '{r}.level IS NULL',
      labelKey: 'x',
    ),
  ],
);

const fixtureEquipment = QueryEntity(
  subject: QuerySubject.equipment,
  table: 'equipment',
  fields: [
    QueryField(
      key: 'type',
      type: FieldType.enumName,
      sql: '{r}.type',
      emptySql: '{r}.type IS NULL',
      labelKey: 'x',
      enumValues: ['wetsuit', 'drysuit', 'bcd', 'regulator'],
    ),
  ],
);

final fixtureRegistry = QueryRegistry([
  fixtureDives,
  fixtureSites,
  fixtureWeights,
  fixtureBuddies,
  fixtureCertifications,
  fixtureEquipment,
]);

/// The one site the fixture resolver knows.
const kFixtureSite = RefValue('site-1', 'Salt Pier');
