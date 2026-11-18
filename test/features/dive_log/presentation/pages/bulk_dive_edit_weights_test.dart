import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/bulk_dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_collection_mode_selector.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpBulk(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith((ref) {
            return DiveListNotifier(repository, ref);
          }),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ].cast(),
        child: const MaterialApp(
          // Pinned: an unpinned MaterialApp resolves against the host
          // machine's locales.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BulkDiveEditPage(diveIds: ['d1', 'd2'], embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Bulk edit never saved weighting feedback, and one feedback value rarely
  // fits several dives, so its Weights editor leaves the row out (#4674).
  testWidgets('the Weights editor shows no weighting feedback row', (
    tester,
  ) async {
    await pumpBulk(tester);

    // Weights is the first owned collection, so its selector comes first.
    final addWeights = find.descendant(
      of: find.byType(BulkCollectionModeSelector).first,
      matching: find.text('Add'),
    );
    await tester.ensureVisible(addWeights);
    await tester.tap(addWeights);
    await tester.pumpAndSettle();

    expect(find.text('Add Weight Entry'), findsOneWidget);
    expect(find.text('How was your weighting?'), findsNothing);
  });
}
