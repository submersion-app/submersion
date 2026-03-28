import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('AppSettings defaultTankPreset', () {
    test('has al80 as default', () {
      const settings = AppSettings();
      expect(settings.defaultTankPreset, 'al80');
    });

    test('has applyDefaultTankToImports false as default', () {
      const settings = AppSettings();
      expect(settings.applyDefaultTankToImports, false);
    });

    test('copyWith updates defaultTankPreset', () {
      const settings = AppSettings();
      final updated = settings.copyWith(defaultTankPreset: 'hp100');
      expect(updated.defaultTankPreset, 'hp100');
    });

    test('copyWith updates applyDefaultTankToImports', () {
      const settings = AppSettings();
      final updated = settings.copyWith(applyDefaultTankToImports: true);
      expect(updated.applyDefaultTankToImports, true);
    });

    test('copyWith can clear defaultTankPreset', () {
      const settings = AppSettings(defaultTankPreset: 'hp100');
      final updated = settings.copyWith(clearDefaultTankPreset: true);
      expect(updated.defaultTankPreset, null);
    });
  });

  group('AppSettings diveDetailSections', () {
    test('defaults to all 17 sections visible', () {
      const settings = AppSettings();
      expect(settings.diveDetailSections.length, 17);
      expect(settings.diveDetailSections.every((s) => s.visible), true);
    });

    test('copyWith updates diveDetailSections', () {
      const settings = AppSettings();
      final custom = [
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.tanks,
          visible: true,
        ),
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoO2,
          visible: false,
        ),
      ];
      final updated = settings.copyWith(diveDetailSections: custom);
      expect(updated.diveDetailSections.length, 2);
      expect(updated.diveDetailSections[0].id, DiveDetailSectionId.tanks);
    });

    test('copyWith can clear diveDetailSections to defaults', () {
      const settings = AppSettings(
        diveDetailSections: [
          DiveDetailSectionConfig(
            id: DiveDetailSectionId.tanks,
            visible: false,
          ),
        ],
      );
      final updated = settings.copyWith(clearDiveDetailSections: true);
      expect(updated.diveDetailSections.length, 17);
      expect(updated.diveDetailSections.every((s) => s.visible), true);
    });

    test('copyWith preserves diveDetailSections when not specified', () {
      final custom = [
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.tanks,
          visible: false,
        ),
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.notes,
          visible: true,
        ),
      ];
      final settings = AppSettings(diveDetailSections: custom);
      final updated = settings.copyWith(themePresetId: 'dark');
      expect(updated.diveDetailSections.length, 2);
      expect(updated.diveDetailSections[0].id, DiveDetailSectionId.tanks);
      expect(updated.diveDetailSections[0].visible, false);
    });

    test('default sections match DiveDetailSectionConfig.defaultSections', () {
      const settings = AppSettings();
      expect(
        settings.diveDetailSections.length,
        DiveDetailSectionConfig.defaultSections.length,
      );
      for (var i = 0; i < settings.diveDetailSections.length; i++) {
        expect(
          settings.diveDetailSections[i].id,
          DiveDetailSectionConfig.defaultSections[i].id,
        );
      }
    });

    test(
      'clearDiveDetailSections takes precedence over diveDetailSections',
      () {
        final custom = [
          const DiveDetailSectionConfig(
            id: DiveDetailSectionId.tanks,
            visible: false,
          ),
        ];
        final settings = AppSettings(diveDetailSections: custom);
        final updated = settings.copyWith(
          diveDetailSections: custom,
          clearDiveDetailSections: true,
        );
        // Clear flag wins — should be defaults, not the custom list
        expect(updated.diveDetailSections.length, 17);
        expect(updated.diveDetailSections.every((s) => s.visible), true);
      },
    );

    test('sequential copyWith operations are independent', () {
      const settings = AppSettings();
      final custom = [
        const DiveDetailSectionConfig(
          id: DiveDetailSectionId.tanks,
          visible: false,
        ),
      ];
      // First copyWith changes sections
      final step1 = settings.copyWith(diveDetailSections: custom);
      // Second copyWith changes theme but not sections
      final step2 = step1.copyWith(themePresetId: 'deep');
      // Sections should be preserved from step1
      expect(step2.diveDetailSections.length, 1);
      expect(step2.diveDetailSections[0].id, DiveDetailSectionId.tanks);
      expect(step2.themePresetId, 'deep');
    });

    test('copyWith with empty list results in empty list', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        diveDetailSections: <DiveDetailSectionConfig>[],
      );
      expect(updated.diveDetailSections.isEmpty, true);
    });

    test('constructor with custom sections preserves them', () {
      const custom = [
        DiveDetailSectionConfig(id: DiveDetailSectionId.notes, visible: false),
        DiveDetailSectionConfig(id: DiveDetailSectionId.media, visible: true),
      ];
      const settings = AppSettings(diveDetailSections: custom);
      expect(settings.diveDetailSections.length, 2);
      expect(settings.diveDetailSections[0].id, DiveDetailSectionId.notes);
      expect(settings.diveDetailSections[0].visible, false);
      expect(settings.diveDetailSections[1].id, DiveDetailSectionId.media);
      expect(settings.diveDetailSections[1].visible, true);
    });
  });
}
