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

    // A UDDF <divetype> element is the file asserting a dive type, so a mode
    // name there is the diver's own classification and is preserved. Only the
    // CSV presets misroute a mode column, so only mapCsvDiveType drops them.
    test('preserves a dive mode name outside the CSV presets', () {
      expect(mapDiveType('CCR'), 'ccr');
      expect(mapDiveType('OC'), 'oc');
    });

    test('still maps the dive modes that are real dive types', () {
      expect(mapDiveType('Freedive'), 'freedive');
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

    test('returns recreational for a blank or unsluggable value', () {
      expect(mapDiveType(null), 'recreational');
      expect(mapDiveType(''), 'recreational');
      expect(mapDiveType('!!!'), 'recreational');
    });

    // generateSlug keeps hyphens, so a slug can be non-empty and still carry
    // no word: a CSV that writes "-" for an empty cell would otherwise mint a
    // dive type named "-".
    test('returns recreational for a value with no letter or digit', () {
      expect(mapDiveType('-'), 'recreational');
      expect(mapDiveType('---'), 'recreational');
      expect(mapDiveType(' - - '), 'recreational');
      expect(mapDiveType('--!--'), 'recreational');
    });

    test('keeps a hyphen inside a value that does have a word', () {
      expect(mapDiveType('Sidemount-CCR'), 'sidemount-ccr');
      expect(mapDiveType('Free-dive'), 'freedive');
    });
  });

  // Subsurface maps its `mode` column and Garmin its `Activity Type` to the
  // dive type field, but those name the breathing loop or the recording
  // mode. Preserving them would give every Subsurface import a custom dive
  // type called "Oc". The exception is CSV-only: mapDiveType's own tests
  // cover the UDDF behaviour, where such a value is the diver's own.
  group('mapCsvDiveType', () {
    test('does not preserve a dive mode as a dive type', () {
      expect(mapCsvDiveType('OC'), 'recreational');
      expect(mapCsvDiveType('CCR'), 'recreational');
      expect(mapCsvDiveType('pSCR'), 'recreational');
      expect(mapCsvDiveType('Gauge Dive'), 'recreational');
      expect(mapCsvDiveType('Single-Gas Dive'), 'recreational');
    });

    test('still maps the dive modes that are real dive types', () {
      expect(mapCsvDiveType('Freedive'), 'freedive');
    });

    // Matched whole, not as a substring: "oc" sits inside "ocean".
    test('a dive mode name inside a longer value is not a dive mode', () {
      expect(mapCsvDiveType('Ocean'), 'ocean');
    });

    // Only the Subsurface `mode` and Garmin `Activity Type` columns reach
    // this, via ValueTransform.diveModeMap. MacDive's real `Dive Type`
    // column keeps ValueTransform.diveTypeMap, so a logbook that genuinely
    // types a dive "CCR" still has it preserved.
    test('a real dive type column preserves a value this one drops', () {
      expect(mapCsvDiveType('CCR'), 'recreational');
      expect(mapDiveType('CCR'), 'ccr');
    });

    test('otherwise behaves exactly as mapDiveType', () {
      for (final v in ['Cenote', 'Sump', 'Cavern / Cave', 'Wreck', '', '!!!']) {
        expect(mapCsvDiveType(v), mapDiveType(v), reason: 'for "$v"');
      }
      expect(mapCsvDiveType(null), mapDiveType(null));
    });
  });
}
