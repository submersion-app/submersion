import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/duplicate_action_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testDiveId = 'existing-1';

const _matchResult = DiveMatchResult(
  diveId: _testDiveId,
  score: 0.85,
  timeDifferenceMs: 60000,
);

const _item = EntityItem(
  title: '2026-01-15 09:00',
  subtitle: '25.0 m · 50 min',
);

Widget _pump({
  required bool isPending,
  DuplicateAction? selectedAction = DuplicateAction.skip,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: DuplicateActionCard(
          item: _item,
          matchResult: _matchResult,
          selectedAction: selectedAction,
          availableActions: const {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
            DuplicateAction.consolidate,
          },
          onActionChanged: (_) {},
          existingDiveId: _testDiveId,
          isPending: isPending,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DuplicateActionCard pending state', () {
    testWidgets('shows NeedsDecisionPill when pending', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_pump(isPending: true));
      await tester.pump();

      expect(find.text('Needs decision'), findsOneWidget);
    });

    testWidgets('does not show pill when not pending', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_pump(isPending: false));
      await tester.pump();

      expect(find.text('Needs decision'), findsNothing);
    });

    testWidgets('renders warning border at resting thickness when pending', (
      tester,
    ) async {
      // Pending cards share the resting 1.5-px border width but carry the
      // tertiary/warning color (asserted in the next test) so the row is
      // flagged without visually out-weighting the surrounding cards.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_pump(isPending: true));
      await tester.pump();

      final card = tester.widget<Card>(find.byType(Card).first);
      final shape = card.shape as RoundedRectangleBorder?;
      expect(shape, isNotNull);
      expect(shape!.side.width, 1.5);
    });

    testWidgets('uses warning tertiary color for border when pending', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_pump(isPending: true));
      await tester.pump();

      final BuildContext context = tester.element(find.byType(Card).first);
      final expectedColor = Theme.of(context).colorScheme.tertiary;

      final card = tester.widget<Card>(find.byType(Card).first);
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.side.color, expectedColor);
    });

    testWidgets(
      'does NOT show action chip when pending and selectedAction is null',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_pump(isPending: true, selectedAction: null));
        await tester.pump();

        // None of the action badge labels should be visible because no
        // decision has been made yet.
        expect(find.text('SKIP'), findsNothing);
        expect(find.text('IMPORT'), findsNothing);
        expect(find.text('CONSOLIDATE'), findsNothing);

        // But the pending pill is still present.
        expect(find.text('Needs decision'), findsOneWidget);
      },
    );

    testWidgets('shows SKIP chip when pending and selectedAction is skip', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _pump(isPending: true, selectedAction: DuplicateAction.skip),
      );
      await tester.pump();

      expect(find.text('SKIP'), findsOneWidget);
    });
  });
}
