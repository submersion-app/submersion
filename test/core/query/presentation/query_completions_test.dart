import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_completions.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({
      QuerySubject.sites: {'Salt Pier': 's1', 'Sand Slope': 's2'},
    }),
    labels: const MapQueryLabels(),
    now: () => DateTime(2026, 9, 25),
  );

  List<String> texts(String text, [int? caret]) => completionsAt(
    text,
    caret ?? text.length,
    context,
  ).map((c) => c.text).toList();

  test('a partial word at the start offers field and relation keys', () {
    expect(texts('dep'), ['depth']);
    expect(
      texts('w'),
      containsAll(['waterTemp', 'waterType', 'weekday', 'weights']),
    );
    expect(texts(''), isEmpty);
  });

  test('after a dot the keys of the related entity are offered', () {
    expect(texts('buddies.'), containsAll(['name', 'certifications']));
    expect(texts('buddies.cert'), ['certifications']);
    expect(texts('buddies.certifications.lev'), ['level']);
    expect(texts('nope.'), isEmpty);
  });

  test('after a colon: none, any and the enum values', () {
    expect(texts('waterType:'), ['none', 'any', 'salt', 'fresh', 'brackish']);
    expect(texts('waterType:fr'), ['fresh']);
    expect(texts('depth:'), ['none', 'any']);
  });

  test('after an operator on an enum field the values are offered', () {
    expect(texts('waterType = '), ['salt', 'fresh', 'brackish']);
    expect(texts('waterType in [salt, '), ['salt', 'fresh', 'brackish']);
  });

  test('after an operator on a relation the ref names are offered, quoted', () {
    expect(texts('site = '), ['"Salt Pier"', '"Sand Slope"']);
    expect(texts('site = Sa'), ['"Salt Pier"', '"Sand Slope"']);
    expect(texts('site = "Sal'), isEmpty);
  });

  test('a completion knows what span it replaces', () {
    final c = completionsAt('depth > 30 AND wat', 18, context);
    expect(c.map((x) => x.text), ['waterTemp', 'waterType']);
    expect(c.first.replaceStart, 15);
    expect(c.first.replaceLength, 3);
    // In the middle of the text, the word before the caret is completed.
    final mid = completionsAt('dep AND depth > 3', 3, context).single;
    expect(mid.replaceStart, 0);
    expect(mid.replaceLength, 3);
  });

  test('keywords are offered after a complete condition', () {
    expect(texts('depth > 30 a'), ['and']);
    expect(texts('depth > 30 '), isEmpty);
  });

  test('an unterminated quote offers nothing', () {
    expect(texts('notes ~ "night'), isEmpty);
  });
}
