import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _new = EntityItem(title: 'Dive A', subtitle: '18 m · 45 min');
const _other = EntityItem(title: 'Dive B', subtitle: '22 m · 60 min');
const _dup = EntityItem(title: 'Dup Dive', subtitle: '25 m · 50 min');

Widget _list({
  required EntityGroup group,
  required Set<int> selected,
  Map<int, DuplicateAction> actions = const {},
  String? Function(int index)? tripNameForIndex,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: EntityReviewList(
        group: group,
        selectedIndices: selected,
        duplicateActions: actions,
        availableActions: DuplicateAction.values.toSet(),
        onToggleSelection: (_) {},
        onDuplicateActionChanged: (_, _) {},
        onSelectAll: () {},
        onDeselectAll: () {},
        existingDiveIdForIndex: (_) => 'existing',
        tripNameForIndex: tripNameForIndex,
      ),
    ),
  ),
);

void main() {
  group('EntityReviewList trip line (#3022)', () {
    testWidgets('a new dive row names its trip', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _list(
          group: const EntityGroup(items: [_new, _other]),
          selected: const {0, 1},
          tripNameForIndex: (i) => i == 0 ? 'Bonaire 2026' : null,
        ),
      );

      expect(find.text('Bonaire 2026'), findsOneWidget);
      expect(find.byIcon(Icons.flight_outlined), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Trip: Bonaire 2026')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a duplicate imported as new names its trip', (tester) async {
      await tester.pumpWidget(
        _list(
          group: const EntityGroup(
            items: [_dup],
            duplicateIndices: {0},
            matchResults: {
              0: DiveMatchResult(
                diveId: 'existing',
                score: 0.85,
                timeDifferenceMs: 60000,
              ),
            },
          ),
          selected: const {0},
          actions: const {0: DuplicateAction.importAsNew},
          tripNameForIndex: (_) => 'Bonaire 2026',
        ),
      );

      expect(find.text('Bonaire 2026'), findsOneWidget);
      expect(find.byIcon(Icons.flight_outlined), findsOneWidget);
    });

    testWidgets('a duplicate merged into its match names the trip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          group: const EntityGroup(
            items: [_dup],
            duplicateIndices: {0},
            matchResults: {
              0: DiveMatchResult(
                diveId: 'existing',
                score: 0.85,
                timeDifferenceMs: 60000,
              ),
            },
          ),
          selected: const {0},
          actions: const {0: DuplicateAction.consolidate},
          tripNameForIndex: (_) => 'Bonaire 2026',
        ),
      );

      expect(find.text('Bonaire 2026'), findsOneWidget);
    });

    testWidgets('a skipped duplicate shows no trip', (tester) async {
      await tester.pumpWidget(
        _list(
          group: const EntityGroup(
            items: [_dup],
            duplicateIndices: {0},
            matchResults: {
              0: DiveMatchResult(
                diveId: 'existing',
                score: 0.85,
                timeDifferenceMs: 60000,
              ),
            },
          ),
          selected: const {},
          actions: const {0: DuplicateAction.skip},
          tripNameForIndex: (_) => 'Bonaire 2026',
        ),
      );

      expect(find.text('Bonaire 2026'), findsNothing);
    });

    testWidgets('no name, no trip line', (tester) async {
      await tester.pumpWidget(
        _list(
          group: const EntityGroup(items: [_new]),
          selected: const {0},
        ),
      );

      expect(find.byIcon(Icons.flight_outlined), findsNothing);
    });
  });
}
