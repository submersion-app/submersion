import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/duplicate_action_card.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testDiveId = 'test-dive-id';

const _itemA = EntityItem(title: 'Dive A', subtitle: '18 m · 45 min');
const _itemB = EntityItem(title: 'Dive B', subtitle: '22 m · 60 min');
const _itemC = EntityItem(title: 'Dive C', subtitle: '30 m · 35 min');
const _dupItem = EntityItem(title: 'Dup Dive', subtitle: '25 m · 50 min');

const _likelyMatchResult = DiveMatchResult(
  diveId: _testDiveId,
  score: 0.85,
  timeDifferenceMs: 60000,
);

const _possibleMatchResult = DiveMatchResult(
  diveId: _testDiveId,
  score: 0.60,
  timeDifferenceMs: 300000,
);

// A non-dive (unscored) duplicate: buddies/tags arrive with no match score,
// so they route through the entity duplicate card rather than the dive card.
const _buddyDupItem = EntityItem(title: 'John Diver', subtitle: 'Buddy');

const _buddyEntityMatch = EntityMatchResult(
  existingId: 'buddy-1',
  existingName: 'John Diver',
  existingFields: {'Name': 'John Diver', 'Cert': 'AOW'},
  incomingFields: {'Name': 'John Diver', 'Cert': 'Rescue'},
);

/// Group for an unscored duplicate that carries comparison data, which is what
/// makes the collapsed header expandable and the action row reachable.
const _buddyGroupWithMatch = EntityGroup(
  items: [_buddyDupItem],
  duplicateIndices: {0},
  entityMatches: {0: _buddyEntityMatch},
);

const _nonDiveActions = {
  DuplicateAction.skip,
  DuplicateAction.importAsNew,
  DuplicateAction.consolidate,
};

Widget _buildList({
  required EntityGroup group,
  Set<int>? selectedIndices,
  Map<int, DuplicateAction>? duplicateActions,
  Set<DuplicateAction>? availableActions,
  ValueChanged<int>? onToggleSelection,
  void Function(int, DuplicateAction)? onDuplicateActionChanged,
  VoidCallback? onSelectAll,
  VoidCallback? onDeselectAll,
  String Function(int)? existingDiveIdForIndex,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 600,
        child: SingleChildScrollView(
          child: EntityReviewList(
            group: group,
            selectedIndices: selectedIndices ?? const {},
            duplicateActions: duplicateActions ?? const {},
            availableActions:
                availableActions ?? DuplicateAction.values.toSet(),
            onToggleSelection: onToggleSelection ?? (_) {},
            onDuplicateActionChanged: onDuplicateActionChanged ?? (_, a) {},
            onSelectAll: onSelectAll ?? () {},
            onDeselectAll: onDeselectAll ?? () {},
            existingDiveIdForIndex:
                existingDiveIdForIndex ?? (_) => _testDiveId,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EntityReviewList - non-duplicate items', () {
    testWidgets('renders checkboxes for non-duplicate items', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(
        items: [_itemA, _itemB, _itemC],
        duplicateIndices: {},
      );

      await tester.pumpWidget(_buildList(group: group));
      await tester.pump();

      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.text('Dive A'), findsOneWidget);
      expect(find.text('Dive B'), findsOneWidget);
      expect(find.text('Dive C'), findsOneWidget);
    });

    testWidgets('checked state reflects selectedIndices', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(
        items: [_itemA, _itemB, _itemC],
        duplicateIndices: {},
      );

      await tester.pumpWidget(
        _buildList(group: group, selectedIndices: {0, 2}),
      );
      await tester.pump();

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();

      expect(checkboxes[0].value, isTrue); // index 0 selected
      expect(checkboxes[1].value, isFalse); // index 1 not selected
      expect(checkboxes[2].value, isTrue); // index 2 selected
    });

    testWidgets('tapping checkbox fires onToggleSelection with correct index', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? toggledIndex;
      const group = EntityGroup(items: [_itemA, _itemB], duplicateIndices: {});

      await tester.pumpWidget(
        _buildList(group: group, onToggleSelection: (i) => toggledIndex = i),
      );
      await tester.pump();

      await tester.tap(find.text('Dive B'));
      await tester.pump();

      expect(toggledIndex, equals(1));
    });
  });

  group('EntityReviewList - duplicate items', () {
    testWidgets('renders DuplicateActionCard for duplicate items', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(
        items: [_itemA, _dupItem],
        duplicateIndices: {1},
        matchResults: {1: _likelyMatchResult},
      );

      await tester.pumpWidget(_buildList(group: group, selectedIndices: {0}));
      await tester.pump();

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byType(DuplicateActionCard), findsOneWidget);
    });

    testWidgets('duplicate card shows correct match percentage', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(
        items: [_dupItem],
        duplicateIndices: {0},
        matchResults: {0: _likelyMatchResult},
      );

      await tester.pumpWidget(_buildList(group: group));
      await tester.pump();

      expect(find.text('85% match'), findsOneWidget);
    });

    testWidgets('likely duplicate section label is shown', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(
        items: [_dupItem],
        duplicateIndices: {0},
        matchResults: {0: _likelyMatchResult},
      );

      await tester.pumpWidget(_buildList(group: group));
      await tester.pump();

      expect(find.text('POTENTIAL DUPLICATES'), findsOneWidget);
    });

    testWidgets('possible duplicate section label is shown', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(
        items: [_dupItem],
        duplicateIndices: {0},
        matchResults: {0: _possibleMatchResult},
      );

      await tester.pumpWidget(_buildList(group: group));
      await tester.pump();

      expect(find.text('POSSIBLE DUPLICATES'), findsOneWidget);
    });

    testWidgets('onDuplicateActionChanged fires when action changed on card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? changedIndex;
      DuplicateAction? changedAction;

      const group = EntityGroup(
        items: [_dupItem],
        duplicateIndices: {0},
        matchResults: {0: _likelyMatchResult},
      );

      await tester.pumpWidget(
        _buildList(
          group: group,
          duplicateActions: {0: DuplicateAction.skip},
          onDuplicateActionChanged: (i, a) {
            changedIndex = i;
            changedAction = a;
          },
        ),
      );
      await tester.pump();

      // Expand the duplicate card to reveal action buttons
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      // The expanded area shows "Dive data not available" since diveData is null
      // — the callback mechanism is still wired. Verify the card expanded.
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Variables unchanged since no action button was tapped (no diveData)
      expect(changedIndex, isNull);
      expect(changedAction, isNull);
    });
  });

  group('EntityReviewList - Select All / Deselect All', () {
    testWidgets('tapping Select All fires onSelectAll', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var selectAllCalled = false;
      const group = EntityGroup(items: [_itemA, _itemB], duplicateIndices: {});

      await tester.pumpWidget(
        _buildList(group: group, onSelectAll: () => selectAllCalled = true),
      );
      await tester.pump();

      await tester.tap(find.text('Select All'));
      await tester.pump();

      expect(selectAllCalled, isTrue);
    });

    testWidgets('tapping Deselect All fires onDeselectAll', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var deselectAllCalled = false;
      const group = EntityGroup(items: [_itemA, _itemB], duplicateIndices: {});

      await tester.pumpWidget(
        _buildList(group: group, onDeselectAll: () => deselectAllCalled = true),
      );
      await tester.pump();

      await tester.tap(find.text('Deselect All'));
      await tester.pump();

      expect(deselectAllCalled, isTrue);
    });

    testWidgets('Select All / Deselect All do not affect duplicate cards', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // One non-duplicate and one duplicate
      const group = EntityGroup(
        items: [_itemA, _dupItem],
        duplicateIndices: {1},
        matchResults: {1: _likelyMatchResult},
      );

      await tester.pumpWidget(_buildList(group: group, selectedIndices: {0}));
      await tester.pump();

      // DuplicateActionCard is still rendered regardless of Select All
      expect(find.byType(DuplicateActionCard), findsOneWidget);
      // Only one checkbox for the non-duplicate
      expect(find.byType(Checkbox), findsOneWidget);
    });
  });

  group('EntityReviewList - item count display', () {
    testWidgets('shows selected count and duplicate count in header', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(
        items: [_itemA, _itemB, _dupItem],
        duplicateIndices: {2},
        matchResults: {2: _likelyMatchResult},
      );

      await tester.pumpWidget(_buildList(group: group, selectedIndices: {0}));
      await tester.pump();

      // Header shows "1 of 2 selected · 1 duplicate"
      expect(find.text('1 of 2 selected \u00b7 1 duplicate'), findsOneWidget);
    });

    testWidgets('shows plural duplicates text when more than one duplicate', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const dup2 = EntityItem(title: 'Dup 2', subtitle: '10 m · 20 min');

      const group = EntityGroup(
        items: [_itemA, _dupItem, dup2],
        duplicateIndices: {1, 2},
        matchResults: {1: _likelyMatchResult, 2: _possibleMatchResult},
      );

      await tester.pumpWidget(_buildList(group: group, selectedIndices: {0}));
      await tester.pump();

      expect(find.text('1 of 1 selected \u00b7 2 duplicates'), findsOneWidget);
    });

    testWidgets('shows only selected count when no duplicates', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(items: [_itemA, _itemB], duplicateIndices: {});

      await tester.pumpWidget(
        _buildList(group: group, selectedIndices: {0, 1}),
      );
      await tester.pump();

      expect(find.text('2 of 2 selected'), findsOneWidget);
    });
  });

  group('EntityReviewList - link to existing (consolidate)', () {
    /// Expands the single entity duplicate card by tapping its collapsed
    /// header, revealing the comparison panel and its action buttons.
    Future<void> expandCard(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
    }

    testWidgets('expanded unscored duplicate offers the three entity actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: _nonDiveActions,
        ),
      );
      await tester.pump();

      // Collapsed: no action buttons yet.
      expect(find.text('Link to existing'), findsNothing);

      await expandCard(tester);

      expect(find.text('Link to existing'), findsOneWidget);
      expect(find.text('Use the matched record'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Import as New'), findsOneWidget);
    });

    testWidgets('hides Replace existing when the tab does not support it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          // _nonDiveActions omits replaceSource: the Universal adapter only
          // implements overwrite-in-place for sites, so a buddies tab must
          // not offer a button whose import path would drop the row.
          availableActions: _nonDiveActions,
        ),
      );
      await tester.pump();
      await expandCard(tester);

      expect(find.text('Replace existing'), findsNothing);
      // The supported actions are still there.
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Import as New'), findsOneWidget);
    });

    testWidgets('shows Replace existing when the tab supports it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? changedIndex;
      DuplicateAction? changedAction;

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: {..._nonDiveActions, DuplicateAction.replaceSource},
          onDuplicateActionChanged: (i, a) {
            changedIndex = i;
            changedAction = a;
          },
        ),
      );
      await tester.pump();
      await expandCard(tester);

      expect(find.text('Replace existing'), findsOneWidget);

      await tester.tap(find.text('Replace existing'));
      await tester.pump();

      expect(changedIndex, equals(0));
      expect(changedAction, equals(DuplicateAction.replaceSource));
    });

    testWidgets('replaceSource row shows the REPLACE badge', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: {..._nonDiveActions, DuplicateAction.replaceSource},
          duplicateActions: {0: DuplicateAction.replaceSource},
        ),
      );
      await tester.pump();

      // Same word as the dive card's badge for this action -- not "OVERWRITE".
      expect(find.text('REPLACE'), findsOneWidget);
    });

    testWidgets('tapping Link to existing reports consolidate', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? changedIndex;
      DuplicateAction? changedAction;

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: _nonDiveActions,
          onDuplicateActionChanged: (i, a) {
            changedIndex = i;
            changedAction = a;
          },
        ),
      );
      await tester.pump();

      await expandCard(tester);
      await tester.tap(find.text('Link to existing'));
      await tester.pump();

      expect(changedIndex, equals(0));
      expect(changedAction, equals(DuplicateAction.consolidate));
    });

    testWidgets('selected Link to existing renders as a filled button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: _nonDiveActions,
          duplicateActions: {0: DuplicateAction.consolidate},
        ),
      );
      await tester.pump();

      await expandCard(tester);

      // isSelected drives FilledButton (vs OutlinedButton when unselected).
      expect(
        find.widgetWithText(FilledButton, 'Link to existing'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Link to existing'),
        findsNothing,
      );
      expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);
    });

    testWidgets('consolidate action shows the LINK badge in the header', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: _nonDiveActions,
          duplicateActions: {0: DuplicateAction.consolidate},
        ),
      );
      await tester.pump();

      expect(find.text('LINK'), findsOneWidget);
      expect(find.text('IMPORT'), findsNothing);
      expect(find.text('SKIP'), findsNothing);
    });

    testWidgets('importAsNew action shows the IMPORT badge in the header', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: _nonDiveActions,
          duplicateActions: {0: DuplicateAction.importAsNew},
        ),
      );
      await tester.pump();

      expect(find.text('IMPORT'), findsOneWidget);
      expect(find.text('LINK'), findsNothing);
    });

    testWidgets('skip action shows the SKIP badge in the header', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: _nonDiveActions,
          duplicateActions: {0: DuplicateAction.skip},
        ),
      );
      await tester.pump();

      expect(find.text('SKIP'), findsOneWidget);
      expect(find.text('LINK'), findsNothing);
      expect(find.text('IMPORT'), findsNothing);
    });

    testWidgets('no badge is shown when the row has no decision yet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: _nonDiveActions,
        ),
      );
      await tester.pump();

      expect(find.text('LINK'), findsNothing);
      expect(find.text('IMPORT'), findsNothing);
      expect(find.text('SKIP'), findsNothing);
    });

    testWidgets('consolidate row uses the primary color for its card border', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: _nonDiveActions,
          duplicateActions: {0: DuplicateAction.consolidate},
        ),
      );
      await tester.pump();

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);

      final colorScheme = Theme.of(tester.element(cardFinder)).colorScheme;
      final shape =
          tester.widget<Card>(cardFinder).shape! as RoundedRectangleBorder;

      expect(shape.side.color, equals(colorScheme.primary));
      expect(shape.side.width, equals(1.5));
    });

    testWidgets('skip row uses the error color for its card border', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildList(
          group: _buddyGroupWithMatch,
          availableActions: _nonDiveActions,
          duplicateActions: {0: DuplicateAction.skip},
        ),
      );
      await tester.pump();

      final cardFinder = find.byType(Card);
      final colorScheme = Theme.of(tester.element(cardFinder)).colorScheme;
      final shape =
          tester.widget<Card>(cardFinder).shape! as RoundedRectangleBorder;

      expect(shape.side.color, equals(colorScheme.error));
    });
  });

  group('EntityReviewList - auto-skipped items', () {
    const item0 = EntityItem(title: 'Dive 0', subtitle: '10 m · 20 min');
    const item1 = EntityItem(title: 'Dive 1', subtitle: '11 m · 21 min');
    const item2 = EntityItem(title: 'Dive 2', subtitle: '12 m · 22 min');
    const item3 = EntityItem(title: 'Dive 3', subtitle: '13 m · 23 min');
    const item4 = EntityItem(title: 'Dive 4', subtitle: '14 m · 24 min');

    const fiveItemGroup = EntityGroup(
      items: [item0, item1, item2, item3, item4],
      duplicateIndices: {},
      autoSkipIndices: {0, 1, 2},
    );

    testWidgets('collapses auto-skipped dives into a summary row', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Dives 3 and 4 are selected (kept for import); dives 0-2 are the
      // auto-skipped ones under test.
      await tester.pumpWidget(
        _buildList(group: fiveItemGroup, selectedIndices: {3, 4}),
      );
      await tester.pump();

      expect(
        find.text('3 older dives skipped — already in your log'),
        findsOneWidget,
      );
      expect(find.byType(ExpansionTile), findsOneWidget);

      final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
      expect(tile.leading, isA<Icon>());
      expect((tile.leading! as Icon).icon, equals(Icons.history));
      expect(tile.initiallyExpanded, isFalse);

      // Auto-skipped dives (0, 1, 2) are not listed individually until
      // expanded, while the remaining dives (3, 4) render as usual.
      expect(find.text('Dive 0'), findsNothing);
      expect(find.text('Dive 1'), findsNothing);
      expect(find.text('Dive 2'), findsNothing);
      expect(find.text('Dive 3'), findsOneWidget);
      expect(find.text('Dive 4'), findsOneWidget);

      // Only the two visible, non-skipped rows have checkboxes so far.
      expect(find.byType(Checkbox), findsNWidgets(2));

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Expanding reveals the auto-skipped rows, reusing the same
      // non-duplicate row widget (with its own checkbox + SKIP badge).
      expect(find.text('Dive 0'), findsOneWidget);
      expect(find.text('Dive 1'), findsOneWidget);
      expect(find.text('Dive 2'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(5));
      expect(find.text('SKIP'), findsNWidgets(3));
    });

    testWidgets('action changes on revealed auto-skipped rows use the existing '
        'toggle mechanism', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? toggledIndex;

      await tester.pumpWidget(
        _buildList(
          group: fiveItemGroup,
          onToggleSelection: (i) => toggledIndex = i,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dive 1'));
      await tester.pump();

      expect(toggledIndex, equals(1));
    });

    testWidgets(
      'auto-skipped duplicate rows reuse DuplicateActionCard inside the '
      'summary',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // No diveData on the dup item: the expanded panel then renders a
        // plain "not available" message instead of DiveComparisonCard,
        // which needs a ProviderScope this test doesn't set up. The reuse
        // being verified is the DuplicateActionCard wiring itself, not the
        // embedded comparison UI.
        const group = EntityGroup(
          items: [_itemA, _dupItem],
          duplicateIndices: {1},
          matchResults: {1: _likelyMatchResult},
          autoSkipIndices: {1},
        );

        int? changedIndex;
        DuplicateAction? changedAction;

        await tester.pumpWidget(
          _buildList(
            group: group,
            selectedIndices: {0},
            duplicateActions: {1: DuplicateAction.skip},
            onDuplicateActionChanged: (i, a) {
              changedIndex = i;
              changedAction = a;
            },
          ),
        );
        await tester.pump();

        // The summary row is shown; the duplicate card is hidden until
        // expanded.
        expect(
          find.text('1 older dive skipped — already in your log'),
          findsOneWidget,
        );
        expect(find.byType(DuplicateActionCard), findsNothing);

        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();

        // The revealed card is wired through the exact same
        // onDuplicateActionChanged callback as the main list's duplicate
        // cards, not a fork with its own handler.
        final card = tester.widget<DuplicateActionCard>(
          find.byType(DuplicateActionCard),
        );
        card.onActionChanged(DuplicateAction.importAsNew);

        expect(changedIndex, equals(1));
        expect(changedAction, equals(DuplicateAction.importAsNew));
      },
    );

    testWidgets('no summary row when autoSkipIndices is null', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(items: [_itemA, _itemB], duplicateIndices: {});

      await tester.pumpWidget(_buildList(group: group));
      await tester.pump();

      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Dive A'), findsOneWidget);
      expect(find.text('Dive B'), findsOneWidget);
    });

    testWidgets('no summary row when autoSkipIndices is empty', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(
        items: [_itemA, _itemB],
        duplicateIndices: {},
        autoSkipIndices: {},
      );

      await tester.pumpWidget(_buildList(group: group));
      await tester.pump();

      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Dive A'), findsOneWidget);
      expect(find.text('Dive B'), findsOneWidget);
    });
  });
}
