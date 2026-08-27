import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveEditPage weighting feedback', () {
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

    Future<void> pumpEditor(WidgetTester tester, String diveId) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveEditPage(diveId: diveId, embedded: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Gas & Gear section is collapsed when editing; its tap target is
      // the collapsed summary row (both test dives get the default tank).
      await tester.ensureVisible(find.text('1 tank · Air'));
      await tester.tap(find.text('1 tank · Air'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('How was your weighting?'));
      await tester.pumpAndSettle();
    }

    testWidgets('pre-selects stored feedback and shows the amount', (
      tester,
    ) async {
      final created = await repository.createDive(
        Dive(
          id: '',
          dateTime: DateTime(2026, 1, 1),
          weightingFeedback: WeightingFeedback.overweighted,
          weightingFeedbackKg: 2.0,
        ),
      );
      await pumpEditor(tester, created.id);

      final segmented = tester.widget<SegmentedButton<WeightingFeedback>>(
        find.byType(SegmentedButton<WeightingFeedback>),
      );
      expect(segmented.selected, {WeightingFeedback.overweighted});
      expect(find.text('2.0'), findsOneWidget);
    });

    testWidgets('amount field appears only for over/underweighted', (
      tester,
    ) async {
      final created = await repository.createDive(
        Dive(id: '', dateTime: DateTime(2026, 1, 1)),
      );
      await pumpEditor(tester, created.id);

      expect(find.text('By about how much (kg)'), findsNothing);

      await tester.tap(find.text('Underweighted'));
      await tester.pumpAndSettle();
      expect(find.text('By about how much (kg)'), findsOneWidget);

      await tester.tap(find.text('Felt right'));
      await tester.pumpAndSettle();
      expect(find.text('By about how much (kg)'), findsNothing);
    });
  });
}
