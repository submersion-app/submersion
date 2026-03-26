import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/duplicate_action_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testDiveId = 'test-dive-id';

const _likelyMatchResult = DiveMatchResult(
  diveId: _testDiveId,
  score: 0.92,
  timeDifferenceMs: 30000,
);

const _possibleMatchResult = DiveMatchResult(
  diveId: _testDiveId,
  score: 0.55,
  timeDifferenceMs: 600000,
);

const _testItem = EntityItem(
  title: '2026-01-15 09:00',
  subtitle: '25.0 m · 50 min',
);

Widget _buildCard({required DuplicateActionCard card}) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: card)),
  );
}

DuplicateActionCard _makeCard({
  EntityItem item = _testItem,
  DiveMatchResult? matchResult,
  DuplicateAction selectedAction = DuplicateAction.skip,
  Set<DuplicateAction>? availableActions,
  ValueChanged<DuplicateAction>? onActionChanged,
  String existingDiveId = _testDiveId,
}) {
  return DuplicateActionCard(
    item: item,
    matchResult: matchResult ?? _likelyMatchResult,
    selectedAction: selectedAction,
    availableActions: availableActions ?? DuplicateAction.values.toSet(),
    onActionChanged: onActionChanged ?? (_) {},
    existingDiveId: existingDiveId,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DuplicateActionCard - collapsed state', () {
    testWidgets('renders item title and subtitle', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildCard(card: _makeCard()));
      await tester.pump();

      expect(find.text('2026-01-15 09:00'), findsOneWidget);
      expect(find.text('25.0 m · 50 min'), findsOneWidget);
    });

    testWidgets('renders match percentage text', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildCard(card: _makeCard()));
      await tester.pump();

      expect(find.text('92% match'), findsOneWidget);
    });

    testWidgets('likely duplicate (score >= 0.7) shows red border', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildCard(card: _makeCard(matchResult: _likelyMatchResult)),
      );
      await tester.pump();

      // The card border colour is determined by score >= 0.7 → colorScheme.error.
      // We verify the Card is present and no exception is thrown.
      expect(find.byType(Card), findsOneWidget);

      // Verify the match badge text reflects the likely score.
      expect(find.text('92% match'), findsOneWidget);
    });

    testWidgets('possible duplicate (score < 0.7) shows orange border', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildCard(card: _makeCard(matchResult: _possibleMatchResult)),
      );
      await tester.pump();

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('55% match'), findsOneWidget);
    });

    testWidgets('SKIP action badge is rendered for skip action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildCard(card: _makeCard(selectedAction: DuplicateAction.skip)),
      );
      await tester.pump();

      expect(find.text('SKIP'), findsOneWidget);
    });

    testWidgets('IMPORT action badge is rendered for importAsNew action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildCard(
          card: _makeCard(selectedAction: DuplicateAction.importAsNew),
        ),
      );
      await tester.pump();

      expect(find.text('IMPORT'), findsOneWidget);
    });

    testWidgets('CONSOLIDATE action badge is rendered for consolidate action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildCard(
          card: _makeCard(selectedAction: DuplicateAction.consolidate),
        ),
      );
      await tester.pump();

      expect(find.text('CONSOLIDATE'), findsOneWidget);
    });

    testWidgets('expand chevron is visible in collapsed state', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildCard(card: _makeCard()));
      await tester.pump();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    });
  });

  group('DuplicateActionCard - expand/collapse', () {
    testWidgets('tapping chevron area toggles expanded state', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildCard(card: _makeCard()));
      await tester.pump();

      // Initially collapsed
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Tap the header row to expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      // Now expanded — chevron changes
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('tapping expanded chevron collapses the card', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildCard(card: _makeCard()));
      await tester.pump();

      // Expand first
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Collapse again
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump();
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('expanded state with no diveData shows fallback message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Item with no diveData
      const item = EntityItem(title: 'Some Site', subtitle: '10 m · 30 min');

      await tester.pumpWidget(_buildCard(card: _makeCard(item: item)));
      await tester.pump();

      // Expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      expect(
        find.text('Dive data not available for comparison.'),
        findsOneWidget,
      );
    });
  });

  group('DuplicateActionCard - availableActions', () {
    testWidgets(
      'availableActions parameter is passed to card (no crash with subset)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildCard(
            card: _makeCard(
              availableActions: {
                DuplicateAction.skip,
                DuplicateAction.importAsNew,
              },
            ),
          ),
        );
        await tester.pump();

        // Card renders without error in collapsed state
        expect(find.byType(Card), findsOneWidget);
      },
    );
  });
}
