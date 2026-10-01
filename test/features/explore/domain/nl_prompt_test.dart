import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/explore_subject_fields.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  test('the prompt names every catalog field and stays inside the budget', () {
    final text = NlPrompt.instructions();
    for (final name in [for (final f in kExploreFields) f.name]) {
      expect(text, contains(name), reason: name);
    }
    expect(text, contains('"schemaVersion": $kQuerySchemaVersion'));
    expect(text, contains('unplaced'));
    // Roughly 4 characters per token; the budget is 2,500 tokens for
    // instructions plus schema, so the text itself stays under 7,000 chars.
    expect(text.length, lessThan(7000));
    expect(text, isNot(contains(String.fromCharCode(0x2014))));
  });

  test('the vocabulary mirrors the Dart enums', () {
    final v = NlPrompt.vocabulary();
    expect(v['schemaVersion'], kQuerySchemaVersion);
    expect(v['fields'], exploreFieldNames());
    expect(v['ops'], ClauseOp.values.map((o) => o.jsonName).toList());
    expect(v['units'], ClauseUnit.values.map((u) => u.jsonName).toList());
    expect(v['mentionKinds'], MentionKind.values.map((k) => k.name).toList());
    expect(v['subjects'], ParsedSubject.values.map((s) => s.name).toList());
  });

  test('enum values are listed from the catalog, as prose', () {
    final text = NlPrompt.instructions();
    expect(text, contains('waterType: salt, fresh or brackish.'));
    expect(text, contains('diveMode: oc, ccr, scr or gauge.'));
    expect(
      text,
      contains(
        'entryMethod: shore, boat, backRoll, giantStride, seatedEntry, '
        'ladder, platform, jetty or other.',
      ),
    );
    expect(text, contains('currentStrength: none, light, moderate or strong.'));
    expect(text, contains('weekday: mon, tue, wed, thu, fri, sat, sun.'));
  });

  test('the cold-water example places SAC and the final stop', () {
    final text = NlPrompt.instructions();
    expect(text, contains('"field":"sacChange"'));
    expect(text, contains('"field":"finalStop","op":"eq","value":"unstable"'));
    // Only the minute mark stays unplaced: there is no N-minutes field.
    expect(text, contains('"unplaced":["after 20 minutes"]'));
    expect(text, contains('bar_min, psi_min'));
  });

  test('the prompt names every subject field and lists its values', () {
    final text = NlPrompt.instructions();
    for (final entry in kExploreSubjectFields.entries) {
      expect(text, contains('${entry.key.name}:'), reason: entry.key.name);
      for (final f in entry.value) {
        expect(text, contains(f.name), reason: f.name);
        for (final v in f.enumValues ?? const <String>[]) {
          expect(text, contains(v), reason: '${f.name} $v');
        }
      }
    }
  });

  test('every example compiles with nothing left over but its own words', () {
    final text = NlPrompt.instructions();
    // An example line starts `{"schemaVersion":3`; the shape line has a
    // space after the colon and `[...]` placeholders, so it never matches.
    final examples = RegExp(r'^\{"schemaVersion":\d.*\}$', multiLine: true)
        .allMatches(text)
        .map(
          (m) =>
              ParsedQuery.fromJson(jsonDecode(m[0]!) as Map<String, Object?>),
        )
        .toList();
    expect(examples.map((e) => e.subject), contains(ParsedSubject.sites));
    expect(examples.map((e) => e.subject), contains(ParsedSubject.equipment));
    for (final e in examples) {
      for (final c in e.clauses) {
        expect(exploreFieldFor(e.subject, c.field), isNotNull, reason: c.field);
      }
    }
  });
}
