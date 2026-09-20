import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  Map<String, Object?> sample() => {
    'schemaVersion': kQuerySchemaVersion,
    'subject': 'dives',
    'clauses': [
      {
        'field': 'depth',
        'op': 'gt',
        'value': 20,
        'unit': 'm',
        'text': 'below 20m',
      },
      {
        'field': 'visibility',
        'op': 'gt',
        'value': 20,
        'unit': 'm',
        'text': 'viz over 20m',
      },
    ],
    'mentions': [
      {'kind': 'species', 'text': 'turtles'},
      {'kind': 'place', 'text': 'Bonaire'},
    ],
    'time': null,
    'unplaced': <String>[],
  };

  test('parses the sample sentence payload', () {
    final q = ParsedQuery.fromJson(sample());
    expect(q.schemaVersion, kQuerySchemaVersion);
    expect(q.subject, QuerySubject.dives);
    expect(q.clauses, hasLength(2));
    expect(q.clauses.first.field, 'depth');
    expect(q.clauses.first.op, ClauseOp.gt);
    expect(q.clauses.first.value, 20);
    expect(q.clauses.first.unit, ClauseUnit.m);
    expect(q.mentions[1].kind, MentionKind.place);
    expect(q.time, isNull);
    expect(q.unplaced, isEmpty);
  });

  test('round-trips through toJson', () {
    final q = ParsedQuery.fromJson(sample());
    expect(ParsedQuery.fromJson(q.toJson()).toJson(), q.toJson());
    expect(jsonEncode(q.toJson()), contains('"gt"'));
  });

  test('a between clause carries two numbers', () {
    final json = sample()
      ..['clauses'] = [
        {
          'field': 'depth',
          'op': 'between',
          'value': [10, 20],
          'unit': 'm',
          'text': '10 to 20m',
        },
      ];
    final q = ParsedQuery.fromJson(json);
    expect(q.clauses.single.value, [10, 20]);
  });

  test('the JSON name of inList is in', () {
    final json = sample()
      ..['clauses'] = [
        {
          'field': 'waterType',
          'op': 'in',
          'value': ['salt'],
          'text': 'salt water',
        },
      ];
    expect(ParsedQuery.fromJson(json).clauses.single.op, ClauseOp.inList);
  });

  test('rejects a wrong schema version', () {
    // Both directions: an older adapter still emitting v1 and a newer one
    // emitting a version this build does not know.
    for (final wrong in [kQuerySchemaVersion - 1, kQuerySchemaVersion + 1]) {
      expect(
        () => ParsedQuery.fromJson(sample()..['schemaVersion'] = wrong),
        throwsA(isA<QuerySchemaException>()),
        reason: '\$wrong',
      );
    }
  });

  test('rejects an unknown op, unit, kind or subject', () {
    expect(
      () => ParsedQuery.fromJson(sample()..['subject'] = 'boats'),
      throwsA(isA<QuerySchemaException>()),
    );
    final badOp = sample()
      ..['clauses'] = [
        {'field': 'depth', 'op': 'near', 'value': 1, 'text': 'x'},
      ];
    expect(
      () => ParsedQuery.fromJson(badOp),
      throwsA(isA<QuerySchemaException>()),
    );
    final badUnit = sample()
      ..['clauses'] = [
        {
          'field': 'depth',
          'op': 'gt',
          'value': 1,
          'unit': 'furlong',
          'text': 'x',
        },
      ];
    expect(
      () => ParsedQuery.fromJson(badUnit),
      throwsA(isA<QuerySchemaException>()),
    );
    final badKind = sample()
      ..['mentions'] = [
        {'kind': 'boat', 'text': 'x'},
      ];
    expect(
      () => ParsedQuery.fromJson(badKind),
      throwsA(isA<QuerySchemaException>()),
    );
  });

  test('rejects a clause missing text or value', () {
    final noText = sample()
      ..['clauses'] = [
        {'field': 'depth', 'op': 'gt', 'value': 1},
      ];
    expect(
      () => ParsedQuery.fromJson(noText),
      throwsA(isA<QuerySchemaException>()),
    );
    final noValue = sample()
      ..['clauses'] = [
        {'field': 'depth', 'op': 'gt', 'text': 'x'},
      ];
    expect(
      () => ParsedQuery.fromJson(noValue),
      throwsA(isA<QuerySchemaException>()),
    );
  });

  test('string-encoded values from a constrained decoder are coerced', () {
    // The Apple schema declares value as a string (one type per property),
    // so numbers, lists and booleans may arrive quoted.
    final json = sample()
      ..['clauses'] = [
        {
          'field': 'depth',
          'op': 'gt',
          'value': '20',
          'unit': 'none',
          'text': 'a',
        },
        {'field': 'depth', 'op': 'between', 'value': '[10, 20]', 'text': 'b'},
        {'field': 'favorite', 'op': 'eq', 'value': 'true', 'text': 'c'},
        {
          'field': 'waterType',
          'op': 'in',
          'value': '["salt","fresh"]',
          'text': 'd',
        },
      ];
    final q = ParsedQuery.fromJson(json);
    expect(q.clauses[0].value, 20);
    expect(q.clauses[0].unit, isNull);
    expect(q.clauses[1].value, [10, 20]);
    expect(q.clauses[2].value, true);
    expect(q.clauses[3].value, ['salt', 'fresh']);
  });

  test('a decoded root that is not an object is a schema mismatch', () {
    // A prompt-only adapter can return any valid JSON at all; a list or a
    // bare string must not escape as a TypeError.
    for (final raw in <Object?>[
      <Object?>[1, 2],
      'turtles',
      42,
      null,
    ]) {
      expect(
        () => ParsedQuery.fromDecoded(raw),
        throwsA(isA<QuerySchemaException>()),
        reason: '$raw',
      );
    }
    expect(
      ParsedQuery.fromDecoded(<String, Object?>{
        'schemaVersion': kQuerySchemaVersion,
        'subject': 'dives',
      }).subject,
      QuerySubject.dives,
    );
  });

  test('missing optional lists default to empty', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
      'subject': 'dives',
    });
    expect(q.clauses, isEmpty);
    expect(q.mentions, isEmpty);
    expect(q.unplaced, isEmpty);
  });

  test('withoutClause and withoutMention drop by index', () {
    final q = ParsedQuery.fromJson(sample());
    expect(q.withoutClause(0).clauses.single.field, 'visibility');
    expect(q.withoutMention(1).mentions.single.kind, MentionKind.species);
  });
}
