import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('AppSettings site detail fields', () {
    test('default to every card visible and the detailed layout', () {
      const settings = AppSettings();
      expect(settings.siteDetailLayout, DiveDetailLayout.detailed);
      expect([
        for (final s in settings.siteDetailSections) s.id,
      ], SiteDetailSectionId.values);
    });

    test('copyWith carries them and leaves the dive fields alone', () {
      const settings = AppSettings();
      const hidden = [
        SiteDetailSectionConfig(id: SiteDetailSectionId.notes, visible: false),
      ];
      final updated = settings.copyWith(
        siteDetailSections: hidden,
        siteDetailLayout: DiveDetailLayout.list,
      );
      expect(updated.siteDetailSections, hidden);
      expect(updated.siteDetailLayout, DiveDetailLayout.list);
      expect(updated.diveDetailLayout, DiveDetailLayout.detailed);
      expect(updated.diveDetailSections, settings.diveDetailSections);
    });

    test('clearSiteDetailSections restores the defaults', () {
      const settings = AppSettings(
        siteDetailSections: [
          SiteDetailSectionConfig(
            id: SiteDetailSectionId.notes,
            visible: false,
          ),
        ],
      );
      final cleared = settings.copyWith(clearSiteDetailSections: true);
      expect(
        cleared.siteDetailSections,
        SiteDetailSectionConfig.defaultSections,
      );
    });
  });

  group('DiverSettingsRepository site detail persistence', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('new settings start at the defaults', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.siteDetailLayout, DiveDetailLayout.detailed);
      expect([
        for (final s in loaded.siteDetailSections) s.id,
      ], SiteDetailSectionId.values);
    });

    test('the order, visibility, fold state and layout round-trip', () async {
      final custom = [
        for (final id in SiteDetailSectionId.values.reversed)
          SiteDetailSectionConfig(
            id: id,
            visible: id != SiteDetailSectionId.tide,
            expanded: id == SiteDetailSectionId.depth,
          ),
      ];
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        AppSettings(
          siteDetailSections: custom,
          siteDetailLayout: DiveDetailLayout.list,
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.siteDetailLayout, DiveDetailLayout.list);
      expect(
        [for (final s in loaded.siteDetailSections) s.id],
        [for (final s in custom) s.id],
      );
      final tide = loaded.siteDetailSections.firstWhere(
        (s) => s.id == SiteDetailSectionId.tide,
      );
      expect(tide.visible, isFalse);
      final depth = loaded.siteDetailSections.firstWhere(
        (s) => s.id == SiteDetailSectionId.depth,
      );
      expect(depth.expanded, isTrue);
    });

    test('null columns read back as the defaults', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        'UPDATE diver_settings SET site_detail_sections = NULL, '
        "site_detail_layout = NULL WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.siteDetailLayout, DiveDetailLayout.detailed);
      expect([
        for (final s in loaded.siteDetailSections) s.id,
      ], SiteDetailSectionId.values);
    });

    test('writing the site fields leaves the dive fields alone', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          diveDetailLayout: DiveDetailLayout.list,
          siteDetailLayout: DiveDetailLayout.detailed,
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.diveDetailLayout, DiveDetailLayout.list);
      expect(loaded.siteDetailLayout, DiveDetailLayout.detailed);
    });
  });
}
