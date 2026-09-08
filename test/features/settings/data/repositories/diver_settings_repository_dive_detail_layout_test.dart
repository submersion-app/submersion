import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('AppSettings.diveDetailLayout', () {
    test('defaults to detailed so upgrading changes no page', () {
      const settings = AppSettings();
      expect(settings.diveDetailLayout, DiveDetailLayout.detailed);
    });

    test('copyWith carries the layout and leaves the rest alone', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        diveDetailLayout: DiveDetailLayout.list,
      );
      expect(updated.diveDetailLayout, DiveDetailLayout.list);
      expect(updated.diveDetailSections, settings.diveDetailSections);
      expect(updated.depthUnit, settings.depthUnit);
    });

    // The two live in the same settings row and are edited from the same
    // menu, so a write to one must not clobber the other.
    test('the layout and the section list are independent', () {
      const hidden = [
        DiveDetailSectionConfig(id: DiveDetailSectionId.notes, visible: false),
      ];
      const settings = AppSettings(
        diveDetailSections: hidden,
        diveDetailLayout: DiveDetailLayout.detailed,
      );
      final updated = settings.copyWith(
        diveDetailLayout: DiveDetailLayout.list,
      );
      expect(updated.diveDetailSections, hidden);
    });
  });

  group('DiverSettingsRepository dive detail layout persistence', () {
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

    test('new settings default to the detailed layout', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.diveDetailLayout, DiveDetailLayout.detailed);
    });

    for (final layout in DiveDetailLayout.values) {
      test('round-trips ${layout.name}', () async {
        await repository.createSettingsForDiver('d1');
        await repository.updateSettingsForDiver(
          'd1',
          AppSettings(diveDetailLayout: layout),
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.diveDetailLayout, layout);
      });
    }

    test('a null column reads back as detailed', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        "UPDATE diver_settings SET dive_detail_layout = NULL "
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.diveDetailLayout, DiveDetailLayout.detailed);
    });

    test('an unrecognized stored layout degrades to detailed', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        "UPDATE diver_settings SET dive_detail_layout = 'nonsense' "
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.diveDetailLayout, DiveDetailLayout.detailed);
    });

    test('a legacy decoO2 section order survives the round trip', () async {
      await repository.createSettingsForDiver('d1');
      // What a diver who had hidden the combined deco/tissue panel has
      // stored. Both halves must come back hidden.
      await db.customStatement(
        'UPDATE diver_settings SET dive_detail_sections = '
        '\'[{"id":"decoO2","visible":false},{"id":"notes","visible":true}]\' '
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      final sections = loaded!.diveDetailSections;
      expect(
        sections
            .firstWhere((s) => s.id == DiveDetailSectionId.decoStatus)
            .visible,
        isFalse,
      );
      expect(
        sections
            .firstWhere((s) => s.id == DiveDetailSectionId.tissueLoading)
            .visible,
        isFalse,
      );
      // And the section that only exists now arrives visible, at the top.
      expect(sections.first.id, DiveDetailSectionId.profile);
      expect(sections.first.visible, isTrue);
    });
  });
}
