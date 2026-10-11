// Covers the in-batch-duplicate branch of DiveComparisonCard: when
// `existingDiveId` is empty there is no database dive to load or compare, so
// the card shows an explanatory line and still renders the action selector.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/dive_comparison_card.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/duplicate_action_card.dart';
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

  group('with the other copy at hand (#3110)', () {
    List<Map<String, dynamic>> profile(double depth) => [
      {'timestamp': 0, 'depth': 0.0},
      {'timestamp': 600, 'depth': depth},
      {'timestamp': 2700, 'depth': 0.0},
    ];
    final partner = IncomingDiveData.fromImportMap({
      'dateTime': DateTime(2024, 1, 1, 10),
      'maxDepth': 18.0,
      'duration': const Duration(minutes: 45),
      'diveNumber': 300,
      'waterTemp': 27.0,
      'profile': profile(18.0),
    });
    final withProfile = IncomingDiveData.fromImportMap({
      'dateTime': DateTime(2024, 1, 1, 10),
      'maxDepth': 18.0,
      'duration': const Duration(minutes: 45),
      'profile': profile(17.8),
    });

    Future<void> pumpPair(WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          DiveComparisonCard(
            incoming: withProfile,
            existingDiveId: '',
            matchScore: 1.0,
            incomingLabel: 'Incoming',
            onActionChanged: (_) {},
            availableActions: const {
              DuplicateAction.skip,
              DuplicateAction.importAsNew,
            },
            inBatchPartner: partner,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('says what each button keeps', (tester) async {
      await pumpPair(tester);
      expect(
        find.text(
          'This dive is in the import twice. Skip keeps the other copy; '
          'Import as New keeps this one instead.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Duplicate of another dive in this import batch.'),
        findsNothing,
      );
    });

    testWidgets('the duplicate card passes its partner to the comparison', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(
            child: DuplicateActionCard(
              item: EntityItem(
                title: 'Copy',
                subtitle: '',
                diveData: withProfile,
              ),
              matchResult: const DiveMatchResult(
                diveId: '',
                inBatchIndex: 0,
                score: 1.0,
                timeDifferenceMs: 0,
              ),
              selectedAction: DuplicateAction.skip,
              availableActions: const {
                DuplicateAction.skip,
                DuplicateAction.importAsNew,
              },
              onActionChanged: (_) {},
              existingDiveId: '',
              inBatchPartner: partner,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(find.text('Other copy (#300)'), findsWidgets);
    });

    testWidgets('the duplicate card never offers Consolidate for a copy', (
      tester,
    ) async {
      // The universal adapter offers Consolidate for dive duplicates, but a
      // copy of another row has no stored dive to fold into.
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(
            child: DuplicateActionCard(
              item: EntityItem(
                title: 'Copy',
                subtitle: '',
                diveData: withProfile,
              ),
              matchResult: const DiveMatchResult(
                diveId: '',
                inBatchIndex: 0,
                score: 1.0,
                timeDifferenceMs: 0,
              ),
              selectedAction: DuplicateAction.skip,
              availableActions: const {
                DuplicateAction.skip,
                DuplicateAction.importAsNew,
                DuplicateAction.consolidate,
              },
              onActionChanged: (_) {},
              existingDiveId: '',
              inBatchPartner: partner,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(find.text('Skip'), findsWidgets);
      expect(find.text('Consolidate'), findsNothing);
    });

    testWidgets('compares the two copies field by field', (tester) async {
      await pumpPair(tester);
      // The water temperature only the other copy has is a difference,
      // headed by that copy's number.
      expect(find.text('Other copy (#300)'), findsWidgets);
      // Neither copy is stored yet, so the legend does not call one of them
      // the existing dive.
      expect(find.textContaining('Existing:'), findsNothing);
      expect(find.text('Incoming'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
