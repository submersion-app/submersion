import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/dive_comparison_card.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _existingDiveId = 'test-dive-id';

final _testDive = domain.Dive(
  id: _existingDiveId,
  dateTime: DateTime(2026, 1, 15, 9, 0),
  diveNumber: 42,
);

final _testIncoming = IncomingDiveData(
  startTime: DateTime(2026, 1, 15, 9, 0),
  maxDepth: 25.0,
  durationSeconds: 3000,
);

/// Wraps the widget under test with all required providers stubbed out.
Widget _buildCard({required DiveComparisonCard card}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      diveProvider.overrideWith((ref, id) async => _testDive),
      diveProfileProvider.overrideWith((ref, id) async => []),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'DiveComparisonCard - immediate-action mode (backwards compatible)',
    () {
      testWidgets('renders all three action buttons by default', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Import as New'), findsOneWidget);
        expect(find.text('Consolidate'), findsOneWidget);
      });

      testWidgets('fires onSkip when Skip tapped', (tester) async {
        var skipCalled = false;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              onSkip: () => skipCalled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(skipCalled, isTrue);
      });

      testWidgets('fires onImportAsNew when Import as New tapped', (
        tester,
      ) async {
        var importCalled = false;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              onImportAsNew: () => importCalled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import as New'));
        await tester.pump();

        expect(importCalled, isTrue);
      });

      testWidgets('fires onConsolidate when Consolidate tapped', (
        tester,
      ) async {
        var consolidateCalled = false;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              onConsolidate: () => consolidateCalled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Consolidate'));
        await tester.pump();

        expect(consolidateCalled, isTrue);
      });
    },
  );

  group('DiveComparisonCard - tri-state selector mode', () {
    testWidgets('renders all three buttons when selectedAction is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.skip,
            onActionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Import as New'), findsOneWidget);
      expect(find.text('Consolidate'), findsOneWidget);
    });

    testWidgets('active button uses FilledButton style', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.consolidate,
            onActionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The selected button (Consolidate) renders as FilledButton.tonal.
      // Inactive buttons (Skip, Import as New) render as OutlinedButton.
      final filledButtons = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .toList();
      final outlinedButtons = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .toList();

      // Exactly one filled button (the selected one).
      expect(filledButtons.length, 1);
      // Two outlined buttons (the inactive ones).
      expect(outlinedButtons.length, 2);
    });

    testWidgets(
      'tapping Skip calls onActionChanged with DuplicateAction.skip',
      (tester) async {
        DuplicateAction? received;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              selectedAction: DuplicateAction.importAsNew,
              onActionChanged: (action) => received = action,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(received, DuplicateAction.skip);
      },
    );

    testWidgets(
      'tapping Import as New calls onActionChanged with DuplicateAction.importAsNew',
      (tester) async {
        DuplicateAction? received;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              selectedAction: DuplicateAction.skip,
              onActionChanged: (action) => received = action,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import as New'));
        await tester.pump();

        expect(received, DuplicateAction.importAsNew);
      },
    );

    testWidgets(
      'tapping Consolidate calls onActionChanged with DuplicateAction.consolidate',
      (tester) async {
        DuplicateAction? received;
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              selectedAction: DuplicateAction.skip,
              onActionChanged: (action) => received = action,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Consolidate'));
        await tester.pump();

        expect(received, DuplicateAction.consolidate);
      },
    );

    testWidgets('availableActions hides Consolidate button when not in set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.skip,
            onActionChanged: (_) {},
            availableActions: {
              DuplicateAction.skip,
              DuplicateAction.importAsNew,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Import as New'), findsOneWidget);
      expect(find.text('Consolidate'), findsNothing);
    });

    testWidgets('availableActions hides Skip button when not in set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          card: DiveComparisonCard(
            incoming: _testIncoming,
            existingDiveId: _existingDiveId,
            matchScore: 0.95,
            selectedAction: DuplicateAction.importAsNew,
            onActionChanged: (_) {},
            availableActions: {
              DuplicateAction.importAsNew,
              DuplicateAction.consolidate,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsNothing);
      expect(find.text('Import as New'), findsOneWidget);
      expect(find.text('Consolidate'), findsOneWidget);
    });

    testWidgets(
      'availableActions with only one action shows only that button',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              selectedAction: DuplicateAction.consolidate,
              onActionChanged: (_) {},
              availableActions: {DuplicateAction.consolidate},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Skip'), findsNothing);
        expect(find.text('Import as New'), findsNothing);
        expect(find.text('Consolidate'), findsOneWidget);
      },
    );

    testWidgets(
      'does not fire immediate-action callbacks when in tri-state mode',
      (tester) async {
        var legacyCalled = false;
        DuplicateAction? received;

        await tester.pumpWidget(
          _buildCard(
            card: DiveComparisonCard(
              incoming: _testIncoming,
              existingDiveId: _existingDiveId,
              matchScore: 0.95,
              // Both modes wired — tri-state should win.
              onSkip: () => legacyCalled = true,
              selectedAction: DuplicateAction.importAsNew,
              onActionChanged: (action) => received = action,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(legacyCalled, isFalse);
        expect(received, DuplicateAction.skip);
      },
    );
  });
}
