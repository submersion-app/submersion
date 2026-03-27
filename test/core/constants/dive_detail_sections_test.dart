import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';

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
  });
}
