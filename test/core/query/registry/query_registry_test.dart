import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, {List<String> aliases = const []}) => QueryField(
  key: key,
  aliases: aliases,
  type: FieldType.text,
  sql: '{r}.$key',
  emptySql: "{r}.$key IS NULL OR TRIM({r}.$key) = ''",
  labelKey: 'x',
);

final _b = QueryEntity(
  subject: QuerySubject.buddies,
  table: 'buddies',
  fields: [_text('name')],
  relations: const [
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
final _c = QueryEntity(
  subject: QuerySubject.certifications,
  table: 'certifications',
  fields: [_text('level')],
);
final _d = QueryEntity(
  subject: QuerySubject.dives,
  table: 'dives',
  fields: [
    _text('notes', aliases: ['note']),
  ],
  relations: const [
    QueryRelation(
      key: 'buddies',
      aliases: ['buddy'],
      target: QuerySubject.buddies,
      shape: RelationShape.junction,
      joinSql:
          'EXISTS (SELECT 1 FROM dive_buddies j WHERE j.dive_id = {from}.id '
          'AND j.buddy_id = {to}.id)',
      isMany: true,
      labelKey: 'x',
    ),
  ],
);
final registry = QueryRegistry([_d, _b, _c]);

void main() {
  test('resolves a field by key or alias', () {
    final r = resolvePath(registry, _d, FieldPath(['note']));
    expect(r.error, isNull);
    expect(r.field!.key, 'notes');
    expect(r.hops, isEmpty);
  });

  test('resolves a multi-hop path through declared relations', () {
    final r = resolvePath(
      registry,
      _d,
      FieldPath(['buddy', 'certifications', 'level']),
    );
    expect(r.error, isNull);
    expect(r.hops.map((h) => h.key), ['buddies', 'certifications']);
    expect(r.field!.key, 'level');
  });

  test('a path ending in a relation has no field', () {
    final r = resolvePath(registry, _d, FieldPath(['buddies']));
    expect(r.field, isNull);
    expect(r.terminalRelation!.key, 'buddies');
  });

  test('an unknown segment reports where and offers suggestions', () {
    final r = resolvePath(registry, _d, FieldPath(['buddies', 'nmae']));
    expect(r.error!.message, contains('nmae'));
    expect(r.error!.suggestions, contains('name'));
    expect(r.errorSegment, 1);
  });

  test('a path deeper than kMaxPathHops is rejected', () {
    final deep = QueryEntity(
      subject: QuerySubject.sites,
      table: 'sites',
      relations: const [
        QueryRelation(
          key: 'self',
          target: QuerySubject.sites,
          shape: RelationShape.child,
          joinSql: '{to}.id = {from}.id',
          isMany: true,
          labelKey: 'x',
        ),
      ],
      fields: [_text('name')],
    );
    final reg = QueryRegistry([deep]);
    final r = resolvePath(
      reg,
      deep,
      FieldPath(['self', 'self', 'self', 'self', 'self', 'name']),
    );
    expect(r.error!.message, contains('$kMaxPathHops'));
  });
}
