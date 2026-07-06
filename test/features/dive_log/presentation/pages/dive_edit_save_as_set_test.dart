import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Regression test for the r/submersion report: "Save as Set" appeared to do
/// nothing. Root cause: the handler wrote the set with a null diverId, so it
/// was orphaned and invisible to the diver-scoped set list.
void main() {
  group('DiveEditPage save-as-set', () {
    late DiveRepository repository;

    setUp(() async {
      final db = await setUpTestDatabase();
      // Seed without FK enforcement so we don't need a full divers row graph.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('saving gear as a set makes it visible to the current diver', (
      tester,
    ) async {
      // A catalog equipment item, referenced by the dive so the equipment
      // list (and its "Save as Set" action) renders.
      const regulator = EquipmentItem(
        id: 'eq-1',
        name: 'Apeks XTX50',
        type: EquipmentType.regulator,
      );
      await EquipmentRepository().createEquipment(regulator);
      await repository.createDive(
        Dive(
          id: 'd1',
          dateTime: DateTime(2026, 1, 1),
          notes: '',
          equipment: const [regulator],
        ),
      );

      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith(
              (ref) => DiveListNotifier(repository, ref),
            ),
            customTankPresetsProvider.overrideWith((ref) async => []),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-1',
            ),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(diveId: 'd1', embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Gas & Gear starts collapsed when editing an existing dive and sits
      // below the fold. Scroll its collapsed summary bar into view, then tap
      // it (the summary lives inside the toggle InkWell) to expand the section
      // and reveal the equipment list with its "Save as Set" action.
      final gasGearSummary = find.text('1 tank · Air · 1 item');
      await tester.ensureVisible(gasGearSummary);
      await tester.pumpAndSettle();
      await tester.tap(gasGearSummary);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save as Set'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as Set'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .first,
        'Tropical',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Save'),
        ),
      );
      await tester.pumpAndSettle();

      final sets = await EquipmentSetRepository().getAllSets(
        diverId: 'diver-1',
      );
      expect(sets.map((s) => s.name), contains('Tropical'));
    });
  });
}
