import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  group('CertificationLevelCatalog.levelsFor', () {
    test('every agency and null yields a non-empty, duplicate-free list '
        'ending in other', () {
      final agencies = <CertificationAgency?>[
        ...CertificationAgency.values,
        null,
      ];
      for (final agency in agencies) {
        final levels = CertificationLevelCatalog.levelsFor(agency);
        expect(levels, isNotEmpty, reason: 'agency=$agency');
        expect(levels.last, CertificationLevel.other, reason: 'agency=$agency');
        expect(
          levels.toSet().length,
          levels.length,
          reason: 'agency=$agency has duplicates',
        );
      }
    });

    test('display names within each agency list are unique', () {
      final agencies = <CertificationAgency?>[
        ...CertificationAgency.values,
        null,
      ];
      for (final agency in agencies) {
        final names = CertificationLevelCatalog.levelsFor(
          agency,
        ).map((l) => l.displayName).toList();
        expect(
          names.toSet().length,
          names.length,
          reason: 'agency=$agency has duplicate display names',
        );
      }
    });

    test(
      'CMAS ladder is exactly the nine grades from issue #546, in order',
      () {
        final levels = CertificationLevelCatalog.levelsFor(
          CertificationAgency.cmas,
        );
        expect(levels.sublist(0, 9), const [
          CertificationLevel.cmas1StarDiver,
          CertificationLevel.cmas2StarDiver,
          CertificationLevel.cmas3StarDiver,
          CertificationLevel.cmas4StarDiver,
          CertificationLevel.cmas3StarDiverAssistantInstructor,
          CertificationLevel.cmas4StarDiverAssistantInstructor,
          CertificationLevel.cmas1StarInstructor,
          CertificationLevel.cmas2StarInstructor,
          CertificationLevel.cmas3StarInstructor,
        ]);
        // Generic recreational ladder is excluded for CMAS...
        expect(levels, isNot(contains(CertificationLevel.advancedOpenWater)));
        // ...but shared specialties remain available.
        expect(levels, contains(CertificationLevel.nitrox));
      },
    );

    test('tech agency ladder/specialty overlap is deduplicated', () {
      final levels = CertificationLevelCatalog.levelsFor(
        CertificationAgency.tdi,
      );
      expect(levels.where((l) => l == CertificationLevel.nitrox).length, 1);
      // Ladder order wins: nitrox appears first, not in specialty position.
      expect(levels.first, CertificationLevel.nitrox);
    });

    test('ensure appends an out-of-catalog level before other', () {
      final levels = CertificationLevelCatalog.levelsFor(
        CertificationAgency.cmas,
        ensure: CertificationLevel.advancedOpenWater,
      );
      expect(levels, contains(CertificationLevel.advancedOpenWater));
      expect(levels.last, CertificationLevel.other);
    });

    test('ensure of an in-catalog level does not duplicate it', () {
      final levels = CertificationLevelCatalog.levelsFor(
        CertificationAgency.cmas,
        ensure: CertificationLevel.cmas2StarDiver,
      );
      expect(
        levels.where((l) => l == CertificationLevel.cmas2StarDiver).length,
        1,
      );
    });

    test('null agency offers the full generic list', () {
      final levels = CertificationLevelCatalog.levelsFor(null);
      expect(levels, contains(CertificationLevel.openWater));
      expect(levels, contains(CertificationLevel.advancedOpenWater));
      expect(levels, contains(CertificationLevel.courseDirector));
      expect(levels, contains(CertificationLevel.nitrox));
      expect(levels, isNot(contains(CertificationLevel.cmas1StarDiver)));
    });
  });
}
