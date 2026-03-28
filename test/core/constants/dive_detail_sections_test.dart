import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('DiveDetailSectionId', () {
    test('has 17 values', () {
      expect(DiveDetailSectionId.values.length, 17);
    });

    test('values match expected IDs', () {
      expect(DiveDetailSectionId.values.first, DiveDetailSectionId.decoO2);
      expect(DiveDetailSectionId.values.last, DiveDetailSectionId.dataSources);
    });
  });

  group('DiveDetailSectionConfig', () {
    test('constructs with required fields', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.decoO2,
        visible: true,
      );
      expect(config.id, DiveDetailSectionId.decoO2);
      expect(config.visible, true);
    });

    test('copyWith updates visible', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.tanks,
        visible: true,
      );
      final updated = config.copyWith(visible: false);
      expect(updated.id, DiveDetailSectionId.tanks);
      expect(updated.visible, false);
    });

    test('toJson serializes correctly', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.environment,
        visible: false,
      );
      final json = config.toJson();
      expect(json['id'], 'environment');
      expect(json['visible'], false);
    });

    test('fromJson deserializes correctly', () {
      final config = DiveDetailSectionConfig.fromJson({
        'id': 'environment',
        'visible': false,
      });
      expect(config.id, DiveDetailSectionId.environment);
      expect(config.visible, false);
    });

    test('fromJson ignores unknown section IDs', () {
      final config = DiveDetailSectionConfig.tryFromJson({
        'id': 'nonexistent',
        'visible': true,
      });
      expect(config, isNull);
    });
  });

  group('DiveDetailSectionConfig list serialization', () {
    test('sectionsToJson produces valid JSON string', () {
      const sections = [
        DiveDetailSectionConfig(id: DiveDetailSectionId.decoO2, visible: true),
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.details,
          visible: false,
        ),
      ];
      final jsonStr = DiveDetailSectionConfig.sectionsToJson(sections);
      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded.length, 2);
      expect(decoded[0]['id'], 'decoO2');
      expect(decoded[1]['visible'], false);
    });

    test('sectionsFromJson parses and ensures all sections', () {
      const jsonStr =
          '[{"id":"decoO2","visible":true},{"id":"details","visible":false}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      // 2 saved + 15 missing = 17 total
      expect(sections.length, 17);
      expect(sections[0].id, DiveDetailSectionId.decoO2);
      expect(sections[0].visible, true);
      expect(sections[1].id, DiveDetailSectionId.details);
      expect(sections[1].visible, false);
      // Missing sections appended as visible
      expect(sections.sublist(2).every((s) => s.visible), true);
    });

    test('sectionsFromJson skips unknown IDs and ensures all sections', () {
      const jsonStr =
          '[{"id":"decoO2","visible":true},{"id":"unknown","visible":true},{"id":"details","visible":false}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      // 2 known + 15 missing = 17 (unknown skipped)
      expect(sections.length, 17);
      expect(sections[0].id, DiveDetailSectionId.decoO2);
      expect(sections[1].id, DiveDetailSectionId.details);
    });

    test('sectionsFromJson returns defaults for null input', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson(null);
      expect(sections.length, 17);
      expect(sections.every((s) => s.visible), true);
    });

    test('sectionsFromJson returns defaults for empty string', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson('');
      expect(sections.length, 17);
    });

    test('sectionsFromJson returns defaults for invalid JSON', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson('not json');
      expect(sections.length, 17);
    });
  });

  group('defaultSections', () {
    test('contains all 17 section IDs', () {
      expect(DiveDetailSectionConfig.defaultSections.length, 17);
      final ids = DiveDetailSectionConfig.defaultSections
          .map((s) => s.id)
          .toSet();
      expect(ids, DiveDetailSectionId.values.toSet());
    });

    test('all sections are visible by default', () {
      expect(
        DiveDetailSectionConfig.defaultSections.every((s) => s.visible),
        true,
      );
    });

    test('order matches enum declaration order', () {
      for (var i = 0; i < DiveDetailSectionId.values.length; i++) {
        expect(
          DiveDetailSectionConfig.defaultSections[i].id,
          DiveDetailSectionId.values[i],
        );
      }
    });
  });

  group('ensureAllSections', () {
    test('appends missing sections from a saved config', () {
      const saved = [
        DiveDetailSectionConfig(id: DiveDetailSectionId.decoO2, visible: true),
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.details,
          visible: false,
        ),
      ];
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      expect(result.length, 17);
      expect(result[0].id, DiveDetailSectionId.decoO2);
      expect(result[0].visible, true);
      expect(result[1].id, DiveDetailSectionId.details);
      expect(result[1].visible, false);
      expect(result.sublist(2).every((s) => s.visible), true);
    });

    test('returns saved config unchanged when all sections present', () {
      const saved = DiveDetailSectionConfig.defaultSections;
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      expect(result.length, 17);
      for (var i = 0; i < 17; i++) {
        expect(result[i].id, saved[i].id);
        expect(result[i].visible, saved[i].visible);
      }
    });
  });

  group('DiveDetailSectionConfig fromJson edge cases', () {
    test('fromJson defaults visible to true when missing', () {
      final config = DiveDetailSectionConfig.fromJson({'id': 'tanks'});
      expect(config.id, DiveDetailSectionId.tanks);
      expect(config.visible, true);
    });

    test('fromJson throws for unknown id', () {
      expect(
        () => DiveDetailSectionConfig.fromJson({
          'id': 'nonexistent',
          'visible': true,
        }),
        throwsStateError,
      );
    });

    test('fromJson with visible explicitly set to false', () {
      final config = DiveDetailSectionConfig.fromJson({
        'id': 'decoO2',
        'visible': false,
      });
      expect(config.visible, false);
    });

    test('toJson then fromJson round-trip preserves single config', () {
      const original = DiveDetailSectionConfig(
        id: DiveDetailSectionId.sightings,
        visible: false,
      );
      final json = original.toJson();
      final restored = DiveDetailSectionConfig.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.visible, original.visible);
    });
  });

  group('tryFromJson', () {
    test('returns config for valid JSON map', () {
      final config = DiveDetailSectionConfig.tryFromJson({
        'id': 'media',
        'visible': true,
      });
      expect(config, isNotNull);
      expect(config!.id, DiveDetailSectionId.media);
      expect(config.visible, true);
    });

    test('returns null for missing id key', () {
      final config = DiveDetailSectionConfig.tryFromJson({'visible': true});
      expect(config, isNull);
    });

    test('returns null for non-string id', () {
      final config = DiveDetailSectionConfig.tryFromJson({
        'id': 42,
        'visible': true,
      });
      expect(config, isNull);
    });
  });

  group('DiveDetailSectionConfig copyWith edge cases', () {
    test('copyWith without arguments preserves all values', () {
      const config = DiveDetailSectionConfig(
        id: DiveDetailSectionId.environment,
        visible: false,
      );
      final copy = config.copyWith();
      expect(copy.id, DiveDetailSectionId.environment);
      expect(copy.visible, false);
    });
  });

  group('round-trip serialization', () {
    test(
      'sectionsToJson then sectionsFromJson preserves order and visibility',
      () {
        const original = [
          DiveDetailSectionConfig(
            id: DiveDetailSectionId.tanks,
            visible: false,
          ),
          DiveDetailSectionConfig(id: DiveDetailSectionId.notes, visible: true),
          DiveDetailSectionConfig(
            id: DiveDetailSectionId.decoO2,
            visible: true,
          ),
        ];
        final json = DiveDetailSectionConfig.sectionsToJson(original);
        final restored = DiveDetailSectionConfig.sectionsFromJson(json);
        // 3 saved + 14 missing = 17
        expect(restored.length, 17);
        // First 3 preserve original order and visibility
        expect(restored[0].id, DiveDetailSectionId.tanks);
        expect(restored[0].visible, false);
        expect(restored[1].id, DiveDetailSectionId.notes);
        expect(restored[1].visible, true);
        expect(restored[2].id, DiveDetailSectionId.decoO2);
        expect(restored[2].visible, true);
      },
    );

    test('full 17-section round-trip preserves exact order', () {
      final custom = List.of(DiveDetailSectionConfig.defaultSections);
      // Reverse order and toggle some off
      final reversed = custom.reversed.toList();
      reversed[0] = reversed[0].copyWith(visible: false);
      reversed[5] = reversed[5].copyWith(visible: false);
      final json = DiveDetailSectionConfig.sectionsToJson(reversed);
      final restored = DiveDetailSectionConfig.sectionsFromJson(json);
      expect(restored.length, 17);
      for (var i = 0; i < 17; i++) {
        expect(restored[i].id, reversed[i].id);
        expect(restored[i].visible, reversed[i].visible);
      }
    });
  });

  group('ensureAllSections edge cases', () {
    test('handles empty input list', () {
      final result = DiveDetailSectionConfig.ensureAllSections([]);
      expect(result.length, 17);
      expect(result.every((s) => s.visible), true);
    });

    test('preserves custom visibility for existing sections', () {
      const saved = [
        DiveDetailSectionConfig(id: DiveDetailSectionId.tanks, visible: false),
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.buddies,
          visible: false,
        ),
      ];
      final result = DiveDetailSectionConfig.ensureAllSections(saved);
      final tanksConfig = result.firstWhere(
        (s) => s.id == DiveDetailSectionId.tanks,
      );
      final buddiesConfig = result.firstWhere(
        (s) => s.id == DiveDetailSectionId.buddies,
      );
      expect(tanksConfig.visible, false);
      expect(buddiesConfig.visible, false);
    });
  });

  group('sectionsFromJson error recovery', () {
    test('returns defaults when JSON is a map instead of a list', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson(
        '{"foo":"bar"}',
      );
      expect(sections.length, 17);
      expect(sections.every((s) => s.visible), true);
    });

    test('returns defaults when JSON list contains non-map items', () {
      final sections = DiveDetailSectionConfig.sectionsFromJson('[1, 2, 3]');
      expect(sections.length, 17);
      expect(sections.every((s) => s.visible), true);
    });

    test('returns defaults when all entries have unknown IDs', () {
      const jsonStr =
          '[{"id":"foo","visible":true},{"id":"bar","visible":false}]';
      final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
      // All unknown → parsed list empty → returns defaults
      expect(sections.length, 17);
      expect(sections.every((s) => s.visible), true);
    });

    test(
      'preserves valid entries in JSON list with mixed valid/invalid types',
      () {
        const jsonStr = '[{"id":"decoO2","visible":true}, "not a map", 42]';
        final sections = DiveDetailSectionConfig.sectionsFromJson(jsonStr);
        // Non-Map items are skipped; valid decoO2 is preserved; missing sections
        // are appended by ensureAllSections.
        expect(sections.length, 17);
        expect(sections.first.id, DiveDetailSectionId.decoO2);
        expect(sections.first.visible, true);
      },
    );
  });

  group('sectionsFromJson with all sections present', () {
    test('returns exact list when all 17 sections are in JSON', () {
      final allSections = DiveDetailSectionConfig.defaultSections
          .map((s) => s.toJson())
          .toList();
      final json = jsonEncode(allSections);
      final sections = DiveDetailSectionConfig.sectionsFromJson(json);
      expect(sections.length, 17);
    });
  });

  group('DiveDetailSectionId metadata', () {
    test('displayName returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.displayName.isNotEmpty, true);
      }
    });

    test('description returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.description.isNotEmpty, true);
      }
    });

    test('displayName values are correct for each section', () {
      expect(
        DiveDetailSectionId.decoO2.displayName,
        'Deco Status / Tissue Loading',
      );
      expect(
        DiveDetailSectionId.sacSegments.displayName,
        'SAC Rate by Segment',
      );
      expect(DiveDetailSectionId.details.displayName, 'Details');
      expect(DiveDetailSectionId.environment.displayName, 'Environment');
      expect(DiveDetailSectionId.altitude.displayName, 'Altitude');
      expect(DiveDetailSectionId.tide.displayName, 'Tide');
      expect(DiveDetailSectionId.weights.displayName, 'Weights');
      expect(DiveDetailSectionId.tanks.displayName, 'Tanks');
      expect(DiveDetailSectionId.buddies.displayName, 'Buddies');
      expect(DiveDetailSectionId.signatures.displayName, 'Signatures');
      expect(DiveDetailSectionId.equipment.displayName, 'Equipment');
      expect(
        DiveDetailSectionId.sightings.displayName,
        'Marine Life Sightings',
      );
      expect(DiveDetailSectionId.media.displayName, 'Media');
      expect(DiveDetailSectionId.tags.displayName, 'Tags');
      expect(DiveDetailSectionId.notes.displayName, 'Notes');
      expect(DiveDetailSectionId.customFields.displayName, 'Custom Fields');
      expect(DiveDetailSectionId.dataSources.displayName, 'Data Sources');
    });

    test('description values are correct for each section', () {
      expect(
        DiveDetailSectionId.decoO2.description,
        'NDL, ceiling, tissue heat map, O2 toxicity',
      );
      expect(
        DiveDetailSectionId.sacSegments.description,
        'Phase/time segmentation, cylinder breakdown',
      );
      expect(
        DiveDetailSectionId.details.description,
        'Type, location, trip, dive center, interval',
      );
      expect(
        DiveDetailSectionId.environment.description,
        'Air/water temp, visibility, current',
      );
      expect(
        DiveDetailSectionId.altitude.description,
        'Altitude value, category, deco requirement',
      );
      expect(
        DiveDetailSectionId.tide.description,
        'Tide cycle graph and timing',
      );
      expect(
        DiveDetailSectionId.weights.description,
        'Weight breakdown, total weight',
      );
      expect(
        DiveDetailSectionId.tanks.description,
        'Tank list, gas mixes, pressures, per-tank SAC',
      );
      expect(DiveDetailSectionId.buddies.description, 'Buddy list with roles');
      expect(
        DiveDetailSectionId.signatures.description,
        'Buddy/instructor signature display and capture',
      );
      expect(
        DiveDetailSectionId.equipment.description,
        'Equipment used in dive',
      );
      expect(
        DiveDetailSectionId.sightings.description,
        'Species spotted, sighting details',
      );
      expect(DiveDetailSectionId.media.description, 'Photos/videos gallery');
      expect(DiveDetailSectionId.tags.description, 'Dive tags');
      expect(DiveDetailSectionId.notes.description, 'Dive notes/description');
      expect(
        DiveDetailSectionId.customFields.description,
        'User-defined custom fields',
      );
      expect(
        DiveDetailSectionId.dataSources.description,
        'Connected dive computers, source management',
      );
    });

    test('each section has a unique displayName', () {
      final names = DiveDetailSectionId.values
          .map((id) => id.displayName)
          .toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('DiveDetailSectionId localized metadata', () {
    late AppLocalizations l10n;

    setUpAll(() {
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    test('localizedDisplayName returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.localizedDisplayName(l10n).isNotEmpty, true);
      }
    });

    test('localizedDescription returns non-empty string for all values', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.localizedDescription(l10n).isNotEmpty, true);
      }
    });

    test('localizedDisplayName matches displayName for English locale', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.localizedDisplayName(l10n), id.displayName);
      }
    });

    test('localizedDescription matches description for English locale', () {
      for (final id in DiveDetailSectionId.values) {
        expect(id.localizedDescription(l10n), id.description);
      }
    });

    test('localizedDisplayName values are correct for each section', () {
      expect(
        DiveDetailSectionId.decoO2.localizedDisplayName(l10n),
        'Deco Status / Tissue Loading',
      );
      expect(
        DiveDetailSectionId.sacSegments.localizedDisplayName(l10n),
        'SAC Rate by Segment',
      );
      expect(DiveDetailSectionId.details.localizedDisplayName(l10n), 'Details');
      expect(
        DiveDetailSectionId.environment.localizedDisplayName(l10n),
        'Environment',
      );
      expect(
        DiveDetailSectionId.altitude.localizedDisplayName(l10n),
        'Altitude',
      );
      expect(DiveDetailSectionId.tide.localizedDisplayName(l10n), 'Tide');
      expect(DiveDetailSectionId.weights.localizedDisplayName(l10n), 'Weights');
      expect(DiveDetailSectionId.tanks.localizedDisplayName(l10n), 'Tanks');
      expect(DiveDetailSectionId.buddies.localizedDisplayName(l10n), 'Buddies');
      expect(
        DiveDetailSectionId.signatures.localizedDisplayName(l10n),
        'Signatures',
      );
      expect(
        DiveDetailSectionId.equipment.localizedDisplayName(l10n),
        'Equipment',
      );
      expect(
        DiveDetailSectionId.sightings.localizedDisplayName(l10n),
        'Marine Life Sightings',
      );
      expect(DiveDetailSectionId.media.localizedDisplayName(l10n), 'Media');
      expect(DiveDetailSectionId.tags.localizedDisplayName(l10n), 'Tags');
      expect(DiveDetailSectionId.notes.localizedDisplayName(l10n), 'Notes');
      expect(
        DiveDetailSectionId.customFields.localizedDisplayName(l10n),
        'Custom Fields',
      );
      expect(
        DiveDetailSectionId.dataSources.localizedDisplayName(l10n),
        'Data Sources',
      );
    });

    test('localizedDescription values are correct for each section', () {
      expect(
        DiveDetailSectionId.decoO2.localizedDescription(l10n),
        'NDL, ceiling, tissue heat map, O2 toxicity',
      );
      expect(
        DiveDetailSectionId.sacSegments.localizedDescription(l10n),
        'Phase/time segmentation, cylinder breakdown',
      );
      expect(
        DiveDetailSectionId.details.localizedDescription(l10n),
        'Type, location, trip, dive center, interval',
      );
      expect(
        DiveDetailSectionId.environment.localizedDescription(l10n),
        'Air/water temp, visibility, current',
      );
      expect(
        DiveDetailSectionId.altitude.localizedDescription(l10n),
        'Altitude value, category, deco requirement',
      );
      expect(
        DiveDetailSectionId.tide.localizedDescription(l10n),
        'Tide cycle graph and timing',
      );
      expect(
        DiveDetailSectionId.weights.localizedDescription(l10n),
        'Weight breakdown, total weight',
      );
      expect(
        DiveDetailSectionId.tanks.localizedDescription(l10n),
        'Tank list, gas mixes, pressures, per-tank SAC',
      );
      expect(
        DiveDetailSectionId.buddies.localizedDescription(l10n),
        'Buddy list with roles',
      );
      expect(
        DiveDetailSectionId.signatures.localizedDescription(l10n),
        'Buddy/instructor signature display and capture',
      );
      expect(
        DiveDetailSectionId.equipment.localizedDescription(l10n),
        'Equipment used in dive',
      );
      expect(
        DiveDetailSectionId.sightings.localizedDescription(l10n),
        'Species spotted, sighting details',
      );
      expect(
        DiveDetailSectionId.media.localizedDescription(l10n),
        'Photos/videos gallery',
      );
      expect(DiveDetailSectionId.tags.localizedDescription(l10n), 'Dive tags');
      expect(
        DiveDetailSectionId.notes.localizedDescription(l10n),
        'Dive notes/description',
      );
      expect(
        DiveDetailSectionId.customFields.localizedDescription(l10n),
        'User-defined custom fields',
      );
      expect(
        DiveDetailSectionId.dataSources.localizedDescription(l10n),
        'Connected dive computers, source management',
      );
    });

    test('each section has a unique localizedDisplayName', () {
      final names = DiveDetailSectionId.values
          .map((id) => id.localizedDisplayName(l10n))
          .toList();
      expect(names.toSet().length, names.length);
    });
  });
}
