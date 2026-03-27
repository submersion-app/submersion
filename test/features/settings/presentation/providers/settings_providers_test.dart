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
  });
}
