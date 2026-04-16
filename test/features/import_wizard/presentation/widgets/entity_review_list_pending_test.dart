import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/duplicate_action_card.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testDiveId = 'existing-1';

// A non-null IncomingDiveData makes the group look like a "dive tab".
final _diveData = IncomingDiveData(
  startTime: DateTime(2026, 1, 15, 9, 0),
  maxDepth: 25,
  durationSeconds: 3000,
  profile: const [],
);

final _dup0 = EntityItem(
  title: 'Dup 0',
  subtitle: '25 m - 50 min',
  diveData: _diveData,
);
final _dup1 = EntityItem(
  title: 'Dup 1',
  subtitle: '25 m - 50 min',
  diveData: _diveData,
);
final _dup2 = EntityItem(
  title: 'Dup 2',
  subtitle: '25 m - 50 min',
  diveData: _diveData,
);

const _highMatch = DiveMatchResult(
  diveId: _testDiveId,
  score: 0.92,
  timeDifferenceMs: 60000,
);

const _midMatch = DiveMatchResult(
  diveId: _testDiveId,
  score: 0.80,
  timeDifferenceMs: 60000,
);

const _lowMatch = DiveMatchResult(
  diveId: _testDiveId,
  score: 0.72,
  timeDifferenceMs: 120000,
);

// Non-dive entity (no diveData) for "non-dive tab" branches.
const _siteDupItem = EntityItem(title: 'Site Dup', subtitle: 'GPS: 0, 0');

Widget _pumpList({
  required EntityGroup group,
  required Set<int> pendingIndices,
  Set<DuplicateAction>? availableActions,
  void Function(DuplicateAction)? onBulkAction,
  Map<int, DuplicateAction>? duplicateActions,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 1200,
        child: SingleChildScrollView(
          child: EntityReviewList(
            group: group,
            selectedIndices: const {},
            duplicateActions: duplicateActions ?? const {},
            availableActions:
                availableActions ??
                const {
                  DuplicateAction.skip,
                  DuplicateAction.importAsNew,
                  DuplicateAction.consolidate,
                },
            pendingIndices: pendingIndices,
            onToggleSelection: (_) {},
            onDuplicateActionChanged: (_, _) {},
            onBulkAction: onBulkAction ?? (_) {},
            onSelectAll: () {},
            onDeselectAll: () {},
            existingDiveIdForIndex: (_) => _testDiveId,
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
  group('EntityReviewList bulk action row', () {
    testWidgets('not shown when pendingIndices is empty', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final group = EntityGroup(
        items: [_dup0, _dup1],
        duplicateIndices: const {0, 1},
        matchResults: const {0: _highMatch, 1: _midMatch},
      );

      await tester.pumpWidget(
        _pumpList(group: group, pendingIndices: const {}),
      );
      await tester.pump();

      // Neither bulk buttons should be present
      expect(find.textContaining('Skip all'), findsNothing);
      expect(find.textContaining('Import all'), findsNothing);
      expect(find.textContaining('Consolidate matched'), findsNothing);
    });

    testWidgets('shown when pendingIndices is non-empty on a dive tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final group = EntityGroup(
        items: [_dup0, _dup1],
        duplicateIndices: const {0, 1},
        matchResults: const {0: _highMatch, 1: _midMatch},
      );

      await tester.pumpWidget(
        _pumpList(group: group, pendingIndices: const {0, 1}),
      );
      await tester.pump();

      expect(find.text('Skip all (2)'), findsOneWidget);
      // Dive tab uses "Import all as new".
      expect(find.text('Import all as new (2)'), findsOneWidget);
      // Both pending items have score >= 0.7, so consolidate count == 2.
      expect(find.text('Consolidate matched (2)'), findsOneWidget);
    });

    testWidgets(
      'non-dive tab uses "Import all" label not "Import all as new"',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const group = EntityGroup(items: [_siteDupItem], duplicateIndices: {0});

        await tester.pumpWidget(
          _pumpList(
            group: group,
            pendingIndices: const {0},
            availableActions: const {
              DuplicateAction.skip,
              DuplicateAction.importAsNew,
            },
          ),
        );
        await tester.pump();

        expect(find.text('Import all (1)'), findsOneWidget);
        expect(find.text('Import all as new (1)'), findsNothing);
      },
    );

    testWidgets('filters buttons by availableActions (omits consolidate)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final group = EntityGroup(
        items: [_dup0],
        duplicateIndices: const {0},
        matchResults: const {0: _highMatch},
      );

      await tester.pumpWidget(
        _pumpList(
          group: group,
          pendingIndices: const {0},
          availableActions: const {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
          },
        ),
      );
      await tester.pump();

      expect(find.text('Skip all (1)'), findsOneWidget);
      expect(find.text('Import all as new (1)'), findsOneWidget);
      expect(find.textContaining('Consolidate matched'), findsNothing);
    });

    testWidgets('consolidate button is disabled when no pending >= 0.7', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Score is 0.60 (below 0.7 threshold), so consolidate count == 0.
      const belowThresholdMatch = DiveMatchResult(
        diveId: _testDiveId,
        score: 0.60,
        timeDifferenceMs: 60000,
      );

      final group = EntityGroup(
        items: [_dup0],
        duplicateIndices: const {0},
        matchResults: const {0: belowThresholdMatch},
      );

      await tester.pumpWidget(
        _pumpList(group: group, pendingIndices: const {0}),
      );
      await tester.pump();

      final finder = find.widgetWithText(
        OutlinedButton,
        'Consolidate matched (0)',
      );
      expect(finder, findsOneWidget);
      final button = tester.widget<OutlinedButton>(finder);
      expect(button.onPressed, isNull);
    });

    testWidgets('consolidate counts only pending with score >= 0.7', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const belowThresholdMatch = DiveMatchResult(
        diveId: _testDiveId,
        score: 0.60,
        timeDifferenceMs: 60000,
      );

      final group = EntityGroup(
        items: [_dup0, _dup1, _dup2],
        duplicateIndices: const {0, 1, 2},
        matchResults: const {
          0: _highMatch,
          1: belowThresholdMatch,
          2: _lowMatch,
        },
      );

      await tester.pumpWidget(
        _pumpList(group: group, pendingIndices: const {0, 1, 2}),
      );
      await tester.pump();

      // 2 of 3 pending have score >= 0.7 (indices 0 and 2).
      expect(find.text('Consolidate matched (2)'), findsOneWidget);
    });

    testWidgets('Replace Source bulk button shown when action is available', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final group = EntityGroup(
        items: [_dup0, _dup1],
        duplicateIndices: const {0, 1},
        matchResults: const {0: _highMatch, 1: _midMatch},
      );

      DuplicateAction? firedAction;

      await tester.pumpWidget(
        _pumpList(
          group: group,
          pendingIndices: const {0, 1},
          availableActions: const {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
            DuplicateAction.replaceSource,
            DuplicateAction.consolidate,
          },
          onBulkAction: (a) => firedAction = a,
        ),
      );
      await tester.pump();

      // The Replace Source bulk button should be visible
      expect(find.text('Replace all (2)'), findsOneWidget);

      // Tapping it fires onBulkAction with replaceSource
      await tester.tap(find.text('Replace all (2)'));
      await tester.pump();

      expect(firedAction, DuplicateAction.replaceSource);
    });

    testWidgets('tapping bulk Skip button fires onBulkAction with skip', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      DuplicateAction? firedAction;

      final group = EntityGroup(
        items: [_dup0],
        duplicateIndices: const {0},
        matchResults: const {0: _highMatch},
      );

      await tester.pumpWidget(
        _pumpList(
          group: group,
          pendingIndices: const {0},
          onBulkAction: (a) => firedAction = a,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Skip all (1)'));
      await tester.pump();

      expect(firedAction, DuplicateAction.skip);
    });
  });

  group('EntityReviewList pending-first sort', () {
    testWidgets('pending duplicate sorts before non-pending in same section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Three likely duplicates (all >= 0.7). Two are non-pending with the
      // highest scores; one is pending with the lowest score within the
      // section. In the sorted order pending (index 2) must come first.
      final group = EntityGroup(
        items: [_dup0, _dup1, _dup2],
        duplicateIndices: const {0, 1, 2},
        matchResults: const {
          0: _highMatch, // score 0.92
          1: _midMatch, // score 0.80
          2: _lowMatch, // score 0.72
        },
      );

      await tester.pumpWidget(
        _pumpList(group: group, pendingIndices: const {2}),
      );
      await tester.pump();

      // Three DuplicateActionCards should be rendered in some order.
      final cardFinder = find.byType(DuplicateActionCard);
      expect(cardFinder, findsNWidgets(3));

      // Collect cards' top Y coordinates and associated titles.
      final cards = tester.widgetList<DuplicateActionCard>(cardFinder).toList();
      final rects = cards
          .map((w) => tester.getTopLeft(find.byWidget(w)))
          .toList();

      // Find the pending one (Dup 2, which is _lowMatch index 2) and confirm
      // it has the smallest Y (i.e., is first).
      final titles = cards.map((c) => c.item.title).toList();
      final pendingIdx = titles.indexOf('Dup 2');
      expect(pendingIdx, isNot(-1));

      final pendingY = rects[pendingIdx].dy;
      for (var i = 0; i < rects.length; i++) {
        if (i == pendingIdx) continue;
        expect(
          pendingY,
          lessThan(rects[i].dy),
          reason: 'Pending card must render above non-pending card $i',
        );
      }
    });

    testWidgets('non-pending duplicates remain ordered by score descending', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Two non-pending duplicates, both likely. Highest-score first.
      final group = EntityGroup(
        items: [_dup0, _dup1],
        duplicateIndices: const {0, 1},
        matchResults: const {
          0: _midMatch, // 0.80
          1: _highMatch, // 0.92
        },
      );

      await tester.pumpWidget(
        _pumpList(group: group, pendingIndices: const {}),
      );
      await tester.pump();

      final cardFinder = find.byType(DuplicateActionCard);
      expect(cardFinder, findsNWidgets(2));

      final cards = tester.widgetList<DuplicateActionCard>(cardFinder).toList();
      final rects = cards
          .map((w) => tester.getTopLeft(find.byWidget(w)))
          .toList();

      final dup1Idx = cards.indexWhere((c) => c.item.title == 'Dup 1');
      final dup0Idx = cards.indexWhere((c) => c.item.title == 'Dup 0');

      // Dup 1 (higher score 0.92) should render above Dup 0 (lower 0.80).
      expect(rects[dup1Idx].dy, lessThan(rects[dup0Idx].dy));
    });
  });

  group('EntityReviewList isPending wiring', () {
    testWidgets('pending DuplicateActionCard shows Needs decision pill', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final group = EntityGroup(
        items: [_dup0],
        duplicateIndices: const {0},
        matchResults: const {0: _highMatch},
      );

      await tester.pumpWidget(
        _pumpList(group: group, pendingIndices: const {0}),
      );
      await tester.pump();

      // The "Needs decision" pill is the visual signal for isPending on the
      // DuplicateActionCard. One pill means isPending=true was passed.
      expect(find.text('Needs decision'), findsOneWidget);
    });

    testWidgets('non-pending DuplicateActionCard hides Needs decision pill', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final group = EntityGroup(
        items: [_dup0],
        duplicateIndices: const {0},
        matchResults: const {0: _highMatch},
      );

      await tester.pumpWidget(
        _pumpList(group: group, pendingIndices: const {}),
      );
      await tester.pump();

      expect(find.text('Needs decision'), findsNothing);
    });

    testWidgets('pending non-dive _EntityDuplicateCard shows pill', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // No matchResults -> routes through _EntityDuplicateCard (non-dive).
      const group = EntityGroup(items: [_siteDupItem], duplicateIndices: {0});

      await tester.pumpWidget(
        _pumpList(
          group: group,
          pendingIndices: const {0},
          availableActions: const {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
          },
        ),
      );
      await tester.pump();

      expect(find.text('Needs decision'), findsOneWidget);
    });

    testWidgets('non-pending non-dive _EntityDuplicateCard hides pill', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const group = EntityGroup(items: [_siteDupItem], duplicateIndices: {0});

      await tester.pumpWidget(
        _pumpList(
          group: group,
          pendingIndices: const {},
          availableActions: const {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
          },
        ),
      );
      await tester.pump();

      expect(find.text('Needs decision'), findsNothing);
    });
  });
}
