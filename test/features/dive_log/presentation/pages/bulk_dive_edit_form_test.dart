import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
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
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: DiveEditPage(bulkDiveIds: ['d1', 'd2'], embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders gated Logistics + Notes fields', (tester) async {
      await pumpBulk(tester);

      // 5 Logistics gates (dive center, trip, dive type, rating, favorite)
      // + 1 Notes gate.
      expect(find.byType(BulkFieldGate), findsNWidgets(6));
      expect(find.text('Favorite'), findsOneWidget);
    });

    testWidgets('toggling a gate enables its checkbox', (tester) async {
      await pumpBulk(tester);

      final firstCheckbox = find.byType(Checkbox).first;
      expect(tester.widget<Checkbox>(firstCheckbox).value, isFalse);
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(firstCheckbox).value, isTrue);
    });
  });
}
