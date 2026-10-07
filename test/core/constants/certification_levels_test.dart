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

    test('tech agency ladder/specialty overlap is deduplicated (IANTD)', () {
      // IANTD and PSAI stay on the shared generic tech ladder (issue #3072
      // gave TDI its own structure; IANTD/PSAI are untouched).
      final levels = CertificationLevelCatalog.levelsFor(
        CertificationAgency.iantd,
      );
      expect(levels.where((l) => l == CertificationLevel.nitrox).length, 1);
      // Ladder order wins: nitrox appears first, not in specialty position.
      expect(levels.first, CertificationLevel.nitrox);
    });

    test('TDI ladder/specialty overlap has none, each level appears once '
        '(issue #3072)', () {
      final levels = CertificationLevelCatalog.levelsFor(
        CertificationAgency.tdi,
      );
      expect(levels.toSet().length, levels.length);
      expect(levels.first, CertificationLevel.tdiNitroxDiver);
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

  group('CertificationLevelCatalog.specialtiesFor', () {
    test('excludes specialties already on the agency ladder (IANTD)', () {
      // The shared tech ladder (IANTD/PSAI) contains nitrox, cavern and cave.
      final specialties = CertificationLevelCatalog.specialtiesFor(
        CertificationAgency.iantd,
      );
      expect(specialties, isNot(contains(CertificationLevel.nitrox)));
      expect(specialties, isNot(contains(CertificationLevel.cave)));
      expect(specialties, contains(CertificationLevel.wreck));
    });

    test('TDI specialties are its own Rebreather/Service/Overhead courses, '
        'not the shared cross-agency pool (issue #3072)', () {
      final specialties = CertificationLevelCatalog.specialtiesFor(
        CertificationAgency.tdi,
      );
      expect(specialties, contains(CertificationLevel.tdiFullCaveDiver));
      expect(specialties, contains(CertificationLevel.tdiAirDiluentCcrDiver));
      expect(specialties, isNot(contains(CertificationLevel.wreck)));
      expect(specialties, isNot(contains(CertificationLevel.nitrox)));
    });

    test('returns the full specialty set for a ladder with no overlap', () {
      expect(
        CertificationLevelCatalog.specialtiesFor(CertificationAgency.padi),
        CertificationLevelCatalog.specialties,
      );
    });

    for (final agency in [...CertificationAgency.values, null]) {
      test('ladder + specialties + other reproduces levelsFor '
          '(${agency?.name ?? 'null'})', () {
        expect([
          ...CertificationLevelCatalog.ladderFor(agency),
          ...CertificationLevelCatalog.specialtiesFor(agency),
          CertificationLevel.other,
        ], CertificationLevelCatalog.levelsFor(agency));
      });
    }
  });

  group('ACUC and DAN (issue #690)', () {
    test('ACUC ladder is its own progression in rank order', () {
      expect(CertificationLevelCatalog.ladderFor(CertificationAgency.acuc), [
        CertificationLevel.acucScubaDiver,
        CertificationLevel.openWater,
        CertificationLevel.acucAdvancedDiver,
        CertificationLevel.acucRescueLeader,
        CertificationLevel.masterDiver,
        CertificationLevel.acucUnderwaterGuide,
        CertificationLevel.acucTeachingAssistant,
        CertificationLevel.acucOpenWaterInstructor,
        CertificationLevel.acucAdvancedInstructor,
        CertificationLevel.acucInstructorTrainer,
        CertificationLevel.acucInstructorTrainerEvaluator,
      ]);
    });

    test('ACUC offers the shared diving specialties', () {
      expect(
        CertificationLevelCatalog.specialtiesFor(CertificationAgency.acuc),
        CertificationLevelCatalog.specialties,
      );
    });

    test('DAN ladder holds first-aid credentials, never diver grades', () {
      expect(CertificationLevelCatalog.ladderFor(CertificationAgency.dan), [
        CertificationLevel.danBls,
        CertificationLevel.danEmergencyOxygen,
        CertificationLevel.danDfaPro,
        CertificationLevel.danDemp,
        CertificationLevel.danInstructor,
        CertificationLevel.danInstructorTrainer,
      ]);
      final offered = CertificationLevelCatalog.levelsFor(
        CertificationAgency.dan,
      );
      expect(offered, isNot(contains(CertificationLevel.openWater)));
      expect(offered, isNot(contains(CertificationLevel.trimix)));
    });

    test('DAN specialties replace the diving specialties', () {
      expect(
        CertificationLevelCatalog.specialtiesFor(CertificationAgency.dan),
        [
          CertificationLevel.danAdvancedOxygen,
          CertificationLevel.danNeurologicalAssessment,
          CertificationLevel.danMarineLifeInjuries,
        ],
      );
    });
  });

  group('fromId', () {
    test('returns the built-in for its enum name and null otherwise', () {
      expect(CertificationAgency.fromId('acuc'), CertificationAgency.acuc);
      expect(CertificationAgency.fromId('3f1c-uuid'), isNull);
      expect(CertificationAgency.fromId(null), isNull);
      expect(CertificationLevel.fromId('danDemp'), CertificationLevel.danDemp);
      expect(CertificationLevel.fromId('Open Water'), isNull);
    });
  });
}
