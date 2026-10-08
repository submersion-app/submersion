import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/features/query/app_query_registry.dart';

void main() {
  test('every subject a relation targets has an entity', () {
    for (final e in appQueryRegistry.entities) {
      for (final r in e.relations) {
        expect(
          appQueryRegistry.maybeEntityFor(r.target),
          isNotNull,
          reason: '${e.subject}.${r.key} targets ${r.target}',
        );
      }
    }
  });

  test('the request examples resolve on the dive entity', () {
    final dives = appQueryRegistry.entityFor(QuerySubject.dives);
    for (final path in const [
      ['weights'],
      ['gear', 'type'],
      ['waterTemp'],
      ['temp'],
      ['buddies', 'certifications', 'level'],
      ['site', 'country'],
      ['tanks', 'o2'],
      ['customFields', 'key'],
      ['weight'],
      ['deco'],
      ['year'],
    ]) {
      expect(
        resolvePath(appQueryRegistry, dives, FieldPath(path)).error,
        isNull,
        reason: path.join('.'),
      );
    }
  });

  test('keys and aliases are unique within an entity', () {
    for (final e in appQueryRegistry.entities) {
      final names = e.segmentNames.toList();
      expect(
        names.toSet().length,
        names.length,
        reason: '${e.subject}: $names',
      );
    }
  });

  test('label keys follow the convention', () {
    for (final e in appQueryRegistry.entities) {
      for (final f in e.fields) {
        expect(f.labelKey, 'query_${e.subject.name}_${f.key}');
      }
      for (final r in e.relations) {
        expect(r.labelKey, 'query_${e.subject.name}_${r.key}');
      }
    }
  });
}
