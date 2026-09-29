import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  test('the prompt names every catalog field and stays inside the budget', () {
    final text = NlPrompt.instructions();
    for (final name in DiveFieldCatalog.jsonNames) {
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
    expect(v['fields'], DiveFieldCatalog.jsonNames);
    expect(v['ops'], ClauseOp.values.map((o) => o.jsonName).toList());
    expect(v['units'], ClauseUnit.values.map((u) => u.jsonName).toList());
    expect(v['mentionKinds'], MentionKind.values.map((k) => k.name).toList());
    expect(v['subjects'], QuerySubject.values.map((s) => s.name).toList());
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
}
