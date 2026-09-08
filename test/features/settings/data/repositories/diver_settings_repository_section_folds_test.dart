import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Which sections the diver left unfolded rides inside the existing
/// dive_detail_sections JSON rather than a column of its own, so these tests
/// guard that the repository carries the flag across a save/load.
void main() {
  group('DiverSettingsRepository section fold persistence', () {
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

    test('new settings start with every section folded', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.diveDetailSections.every((s) => !s.expanded), isTrue);
    });

    test('an unfolded section survives a round-trip', () async {
      await repository.createSettingsForDiver('d1');
      final sections = [
        for (final section in DiveDetailSectionConfig.defaultSections)
          section.id == DiveDetailSectionId.notes
              ? section.copyWith(expanded: true)
              : section,
      ];
      await repository.updateSettingsForDiver(
        'd1',
        AppSettings(diveDetailSections: sections),
      );

      final loaded = await repository.getSettingsForDiver('d1');
      final unfolded = loaded!.diveDetailSections
          .where((s) => s.expanded)
          .map((s) => s.id)
          .toList();
      expect(unfolded, [DiveDetailSectionId.notes]);
    });

    // Visibility and fold state share one blob, so writing one must not
    // silently reset the other.
    test('fold state and visibility persist independently', () async {
      await repository.createSettingsForDiver('d1');
      final sections = [
        for (final section in DiveDetailSectionConfig.defaultSections)
          switch (section.id) {
            DiveDetailSectionId.notes => section.copyWith(expanded: true),
            DiveDetailSectionId.tanks => section.copyWith(visible: false),
            _ => section,
          },
      ];
      await repository.updateSettingsForDiver(
        'd1',
        AppSettings(diveDetailSections: sections),
      );

      final loaded = await repository.getSettingsForDiver('d1');
      final byId = {for (final s in loaded!.diveDetailSections) s.id: s};
      expect(byId[DiveDetailSectionId.notes]!.expanded, isTrue);
      expect(byId[DiveDetailSectionId.notes]!.visible, isTrue);
      expect(byId[DiveDetailSectionId.tanks]!.visible, isFalse);
      expect(byId[DiveDetailSectionId.tanks]!.expanded, isFalse);
    });
  });
}
