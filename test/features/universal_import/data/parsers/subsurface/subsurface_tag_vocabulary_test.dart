import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface/subsurface_tag_vocabulary.dart';

void main() {
  group('subsurfaceTagDiveType', () {
    test('maps the cave family to its own dive types', () {
      expect(subsurfaceTagDiveType('cave'), 'cave');
      expect(subsurfaceTagDiveType('cavern'), 'cavern');
    });

    test('a cavern tag never resolves to cave', () {
      // 'cavern' contains 'cave', so a substring match would classify a
      // cavern dive as a cave dive. Matching is exact for that reason.
      expect(subsurfaceTagDiveType('cavern'), isNot('cave'));
    });

    test('maps the rest of the Subsurface built-in vocabulary', () {
      expect(subsurfaceTagDiveType('wreck'), 'wreck');
      expect(subsurfaceTagDiveType('boat'), 'boat');
      expect(subsurfaceTagDiveType('shore'), 'shore');
      expect(subsurfaceTagDiveType('drift'), 'drift');
      expect(subsurfaceTagDiveType('deep'), 'deep');
      expect(subsurfaceTagDiveType('ice'), 'ice');
      expect(subsurfaceTagDiveType('altitude'), 'altitude');
      expect(subsurfaceTagDiveType('night'), 'night');
      expect(subsurfaceTagDiveType('student'), 'training');
    });

    test('leaves tags that classify the site or nothing at all unmapped', () {
      for (final tag in ['pool', 'lake', 'river', 'fresh', 'photo', 'video']) {
        expect(subsurfaceTagDiveType(tag), isNull, reason: tag);
      }
    });

    test('ignores case and surrounding whitespace', () {
      expect(subsurfaceTagDiveType('  Cave '), 'cave');
      expect(subsurfaceTagDiveType('CAVERN'), 'cavern');
    });

    test('a tag outside the built-in vocabulary maps to nothing', () {
      expect(subsurfaceTagDiveType('cave diving'), isNull);
      expect(subsurfaceTagDiveType('sardine run'), isNull);
      expect(subsurfaceTagDiveType(''), isNull);
    });
  });

  group('subsurfaceTagSiteType', () {
    test('maps the cave family and the water bodies', () {
      expect(subsurfaceTagSiteType('cave'), 'cave');
      expect(subsurfaceTagSiteType('cavern'), 'cavern');
      expect(subsurfaceTagSiteType('wreck'), 'wreck');
      expect(subsurfaceTagSiteType('pool'), 'pool');
      expect(subsurfaceTagSiteType('lake'), 'lake');
      expect(subsurfaceTagSiteType('river'), 'river');
    });

    test('a cavern tag never suggests a cave site', () {
      expect(subsurfaceTagSiteType('cavern'), isNot('cave'));
    });

    test('leaves tags that describe only the dive unmapped', () {
      for (final tag in [
        'boat',
        'shore',
        'drift',
        'deep',
        'ice',
        'altitude',
        'night',
        'student',
        'instructor',
        'fresh',
      ]) {
        expect(subsurfaceTagSiteType(tag), isNull, reason: tag);
      }
    });

    test('every mapped site type is a seeded built-in slug', () {
      for (final slug in kSubsurfaceTagSiteTypes.values) {
        expect(kBuiltInSiteTypeIds, contains(slug));
      }
    });
  });

  group('the vocabulary stays inside the seeded slugs', () {
    test('every mapped dive type is seeded by kSeedBuiltInDiveTypesSql', () {
      final seeded = RegExp(
        "SELECT '([a-z_]+)'",
      ).allMatches(kSeedBuiltInDiveTypesSql).map((m) => m.group(1)).toSet();
      for (final slug in kSubsurfaceTagDiveTypes.values) {
        expect(seeded, contains(slug));
      }
    });
  });
}
