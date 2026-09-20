import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/dive_type_mapper.dart';

void main() {
  group('kBuiltInDiveTypeIds', () {
    // The seed is raw SQL, so the Dart set cannot be derived from it. This
    // reads the ids back out of the seed so adding a built-in dive type
    // without extending the set fails here rather than silently making
    // _promoteCustomDiveType treat the new built-in as a custom type.
    test('lists exactly the ids kSeedBuiltInDiveTypesSql seeds', () {
      final seeded = RegExp(
        r"SELECT '([a-z_]+)'(?: AS id)?,",
      ).allMatches(kSeedBuiltInDiveTypesSql).map((m) => m.group(1)!).toSet();

      expect(seeded, isNotEmpty, reason: 'the seed regex matched nothing');
      expect(kBuiltInDiveTypeIds, seeded);
    });
  });

  group('mapDiveType', () {
    test('maps every built-in keyword to its own id', () {
      for (final id in kBuiltInDiveTypeIds) {
        expect(
          mapDiveType(id),
          id,
          reason: 'built-in id $id should map to itself',
        );
      }
    });

    test('preserves an unrecognised value as its slug', () {
      expect(mapDiveType('Cenote'), 'cenote');
      expect(mapDiveType('Sidemount'), 'sidemount');
    });

    test('maps the overhead terms that have a correct built-in', () {
      expect(mapDiveType('Sump'), 'cave');
      expect(mapDiveType('Mine'), 'cave');
    });

    // 'mine' as a bare substring also matches "mineral", "examine" and
    // "determined". A mineral spring is open water, so matching it as a cave
    // dive would be the same over-claiming this change exists to remove.
    test('matches mine as a word, not as a substring', () {
      expect(mapDiveType('Mine'), 'cave');
      expect(mapDiveType('Mine shaft'), 'cave');
      expect(mapDiveType('Flooded mine'), 'cave');
      expect(mapDiveType('Mines'), 'cave');
      expect(mapDiveType('Mineral spring'), 'mineral_spring');
      expect(mapDiveType('Examine'), 'examine');
    });

    // Subsurface maps its `mode` column and Garmin its `Activity Type` to
    // this field, but those name the breathing loop or the recording mode,
    // not the environment. Preserving them would give every Subsurface
    // import a custom dive type called "Oc".
    test('does not preserve a dive mode as a dive type', () {
      expect(mapDiveType('OC'), 'recreational');
      expect(mapDiveType('CCR'), 'recreational');
      expect(mapDiveType('pSCR'), 'recreational');
      expect(mapDiveType('Gauge Dive'), 'recreational');
      expect(mapDiveType('Single-Gas Dive'), 'recreational');
    });

    test('still maps the dive modes that are real dive types', () {
      expect(mapDiveType('Freedive'), 'freedive');
    });

    // Matched whole, not as a substring: "oc" sits inside "ocean".
    test('a dive mode name inside a longer value is not a dive mode', () {
      expect(mapDiveType('Ocean'), 'ocean');
    });

    test('matches tec at a word start only', () {
      expect(mapDiveType('Tec'), 'technical');
      expect(mapDiveType('Tech'), 'technical');
      expect(mapDiveType('Technical'), 'technical');
      expect(mapDiveType('Tec 40'), 'technical');
      expect(mapDiveType('Protected bay'), 'protected_bay');
    });

    test('maps the hyphenated freedive spellings', () {
      expect(mapDiveType('Free-dive'), 'freedive');
      expect(mapDiveType('Free-diving'), 'freedive');
      expect(mapDiveType('Free diving'), 'freedive');
    });

    // "Open Water Diver" is the entry-level certification, so a dive logged
    // under that name is a training dive. A bare "Open water" is not: it is
    // how many logbooks say "an ordinary dive in open water".
    test('maps the open water certification to training', () {
      expect(mapDiveType('Open Water Diver'), 'training');
      expect(mapDiveType('Advanced Open Water Diver'), 'training');
      expect(mapDiveType('open water diver'), 'training');
    });

    test('a bare open water stays recreational', () {
      expect(mapDiveType('Open Water'), 'recreational');
      expect(mapDiveType('Open water dive'), 'recreational');
    });

    // "Fundamentals" is a course, not a fun dive.
    test('matches fun as a word only', () {
      expect(mapDiveType('Fun dive'), 'recreational');
      expect(mapDiveType('Fundamentals'), 'fundamentals');
    });

    test('returns recreational for a blank or unslugabble value', () {
      expect(mapDiveType(null), 'recreational');
      expect(mapDiveType(''), 'recreational');
      expect(mapDiveType('!!!'), 'recreational');
    });
  });
}
