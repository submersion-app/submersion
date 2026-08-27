// Covers the in-batch-duplicate branch of DiveComparisonCard: when
// `existingDiveId` is empty there is no database dive to load or compare, so
// the card shows an explanatory line and still renders the action selector.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/dive_comparison_card.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Widget harness(Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  final incoming = IncomingDiveData.fromImportMap({
    'dateTime': DateTime(2024, 1, 1, 10),
    'maxDepth': 18.0,
    'duration': const Duration(minutes: 45),
  });

  testWidgets('empty existingDiveId renders the in-batch explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        DiveComparisonCard(
          incoming: incoming,
          existingDiveId: '',
          matchScore: 0.9,
          selectedAction: null,
          onActionChanged: (_) {},
          availableActions: const {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
          },
          isPending: true,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Duplicate of another dive in this import batch.'),
      findsOneWidget,
    );
    // No spinner or "existing dive not found" — the DB load is skipped.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('embedded=false wraps the in-batch content in a Card', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        DiveComparisonCard(
          incoming: incoming,
          existingDiveId: '',
          matchScore: 1.0,
          onActionChanged: (_) {},
          availableActions: const {DuplicateAction.skip},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Card), findsWidgets);
    expect(
      find.text('Duplicate of another dive in this import batch.'),
      findsOneWidget,
    );
  });
}
