import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_collection_mode_selector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_field_gate.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveEditPage bulk mode', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    List<dynamic> buildOverrides(List<dynamic> base) {
      return [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith((ref) {
          return DiveListNotifier(repository, ref);
        }),
        customTankPresetsProvider.overrideWith((ref) async => []),
      ];
    }

    Future<void> pumpBulk(WidgetTester tester) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(bulkDiveIds: ['d1', 'd2'], embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders gated Logistics + Notes fields', (tester) async {
      await pumpBulk(tester);

      // 5 Logistics + 9 Conditions + 6 Weather + 1 Notes gates.
      expect(find.byType(BulkFieldGate), findsNWidgets(21));
      expect(find.text('Favorite'), findsOneWidget);
      // 6 collections (tags, equipment, buddies, weights, tanks, sightings)
      // each render a mode selector.
      expect(find.byType(BulkCollectionModeSelector), findsNWidgets(6));
    });

    testWidgets('toggling a gate enables its checkbox', (tester) async {
      await pumpBulk(tester);

      final firstCheckbox = find.byType(Checkbox).first;
      expect(tester.widget<Checkbox>(firstCheckbox).value, isFalse);
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(firstCheckbox).value, isTrue);
    });

    testWidgets('enabling Favorite and saving applies to all dives', (
      tester,
    ) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'bulk-1'),
      );
      final d2 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'bulk-2'),
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(bulkDiveIds: [d1.id, d2.id], embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enable the Favorite gate, then flip its toggle on.
      final favoriteGate = find.ancestor(
        of: find.text('Favorite'),
        matching: find.byType(BulkFieldGate),
      );
      await tester.tap(
        find.descendant(of: favoriteGate, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: favoriteGate, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      // Save, then confirm in the dialog.
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect((await repository.getDiveById(d1.id))!.isFavorite, isTrue);
      expect((await repository.getDiveById(d2.id))!.isFavorite, isTrue);
    });
  });
}
