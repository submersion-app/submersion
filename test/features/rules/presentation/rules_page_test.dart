import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/pages/rules_page.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/widgets/rules_page_menus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';
import 'rules_test_app.dart';

void main() {
  late AppDatabase db;
  late RuleRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    repo = RuleRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<String> make(
    String name, {
    RuleSubject subject = RuleSubject.dives,
    List<RuleAction> actions = const [
      DiveMembershipAction(DiveCollection.diveTypes, MembershipMode.add, [
        'deep',
      ]),
    ],
    QueryNode? condition,
  }) => repo.create(
    diverId: 'me',
    subject: subject,
    name: name,
    triggers: const {RuleTrigger.afterImport},
    condition: condition,
    actions: actions,
  );

  testWidgets('empty state offers New rule', (tester) async {
    await tester.runAsync(() async {
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Nothing runs until you create a rule'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'New rule'), findsOneWidget);
  });

  testWidgets('the empty state\'s example follows the diver\'s units', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await pumpRulesApp(
        tester,
        home: (_) => const RulesPage(),
        settings: MockSettingsNotifier(
          const AppSettings(depthUnit: DepthUnit.feet),
        ),
      );
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('deeper than 100ft'), findsOneWidget);
  });

  testWidgets('a switched-off rule says how it can still run', (tester) async {
    // Run rules and Apply rules leave an off rule out; only its own menu
    // runs it.
    await tester.runAsync(() async {
      final id = await make('Deep');
      await repo.setEnabled(id, false);
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    expect(find.text('Off: runs only from its own menu'), findsOneWidget);
  });

  testWidgets('lists dive and site rules in their sections', (tester) async {
    await tester.runAsync(() async {
      await make('Deep', condition: depthOver(18));
      await make('Boat');
      await make(
        'Red Sea',
        subject: RuleSubject.sites,
        actions: const [AppendSiteDescriptionAction('Warm')],
      );
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    expect(find.text('Dive rules'), findsOneWidget);
    expect(find.text('Site rules'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Deep')).dy,
      lessThan(tester.getTopLeft(find.text('Boat')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Boat')).dy,
      lessThan(tester.getTopLeft(find.text('Red Sea')).dy),
    );
    expect(find.text('Add dive types: Deep'), findsNWidgets(2));
    expect(find.text('Append to description: Warm'), findsOneWidget);
    expect(find.text('Every dive'), findsOneWidget);
    expect(find.textContaining('After import'), findsWidgets);
  });

  testWidgets('a reorder that fails to save puts the rows back', (
    tester,
  ) async {
    // The stored order is unchanged, so the screen must not keep showing
    // an order the rules will not run in.
    await tester.runAsync(() async {
      await make('Alpha');
      await make('Bravo');
      await pumpRulesApp(
        tester,
        home: (_) => const RulesPage(),
        extra: [ruleRepositoryProvider.overrideWithValue(_FailingReorder())],
      );
    });
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_handle).first),
    );
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong. Please try again.'), findsWidgets);
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Bravo')).dy),
    );
  });

  testWidgets('a failed reorder keeps what synced while it ran', (
    tester,
  ) async {
    // Putting back the rows from before the drag would undo a rename that
    // arrived meanwhile.
    await tester.runAsync(() async {
      await make('Alpha');
      await make('Bravo');
      await pumpRulesApp(
        tester,
        home: (_) => const RulesPage(),
        extra: [ruleRepositoryProvider.overrideWithValue(_SyncThenFail(db))],
      );
    });
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_handle).first),
    );
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await gesture.up();
    // The write's own wait runs on the test clock, the database on the real
    // one: advance both.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pumpAndSettle();
    expect(find.text('Charlie'), findsOneWidget);
    expect(find.text('Bravo'), findsNothing);
  });

  testWidgets('the switch turns a rule off', (tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await make('Deep');
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final rule = await tester.runAsync(
      () => repo.getById(id, names: kRuleTestNames),
    );
    expect(rule!.enabled, isFalse);
  });

  testWidgets('a broken action and a problem rule are flagged', (tester) async {
    await tester.runAsync(() async {
      await make(
        'Gone tag',
        actions: const [
          DiveMembershipAction(DiveCollection.tags, MembershipMode.add, [
            'nope',
          ]),
        ],
      );
      final id = await make('Future');
      await db.customStatement(
        "UPDATE rules SET actions_json = '{\"version\":9,\"actions\":[]}' "
        "WHERE id = '$id'",
      );
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('that action is skipped'), findsOneWidget);
    expect(find.textContaining('Made by a newer version'), findsOneWidget);
  });

  testWidgets('a condition naming a deleted site says which', (tester) async {
    // As the saved-queries page does with the same load (one loader, one
    // wording of what it found).
    await tester.runAsync(() async {
      await make(
        'Ghost site',
        condition: ConditionNode(
          FieldPath(['site']),
          QueryOp.eq,
          const RefValue('gone', 'Gone Reef'),
        ),
      );
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Gone Reef'), findsWidgets);
  });

  testWidgets('a condition that will not load is not shown as every dive', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final id = await make('Unreadable', condition: depthOver(18));
      await db.customStatement(
        "UPDATE rules SET condition_json = 'not json' WHERE id = '$id'",
      );
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    expect(find.text('Unreadable'), findsOneWidget);
    expect(find.text('Every dive'), findsNothing);
  });

  testWidgets('the list stays up while the names reload', (tester) async {
    final tick = StateProvider<int>((ref) => 0);
    final reload = Completer<NameIndex>();
    await tester.runAsync(() async {
      await make('Deep');
      await pumpRulesApp(
        tester,
        home: (_) => const RulesPage(),
        names: (ref) =>
            ref.watch(tick) == 0 ? Future.value(kRuleTestNames) : reload.future,
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('Deep'), findsOneWidget);

    // A synced tag or site refreshes the names every rule resolves against.
    ProviderScope.containerOf(
      tester.element(find.byType(RulesPage)),
    ).read(tick.notifier).state++;
    await tester.pump();
    await tester.pump();

    expect(find.text('Deep'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    reload.complete(kRuleTestNames);
    await tester.pumpAndSettle();
  });

  testWidgets('a confirmed delete lands though the row went away', (
    tester,
  ) async {
    final tick = StateProvider<int>((ref) => 0);
    late String id;
    await tester.runAsync(() async {
      id = await make('Deep');
      await pumpRulesApp(
        tester,
        home: (_) => const RulesPage(),
        names: (ref) => ref.watch(tick) == 0
            ? Future.value(kRuleTestNames)
            : Future.error(StateError('names failed')),
      );
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rule actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // While the dialog is up, a reload fails and the rows are rebuilt away.
    ProviderScope.containerOf(
      tester.element(find.byType(RulesPage)),
    ).read(tick.notifier).state++;
    await tester.pumpAndSettle();
    expect(find.byType(RuleRowMenu), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final left = await tester.runAsync(
      () => repo.getById(id, names: kRuleTestNames),
    );
    expect(left, isNull);
  });

  testWidgets('Run on all from a row opens the preview', (tester) async {
    await tester.runAsync(() async {
      await seedRuleDive(db, 'd40', maxDepth: 40);
      await make('Deep', condition: depthOver(30));
      await pumpRulesApp(tester, home: (_) => const RulesPage());
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rule actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run on all dives'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('1 dive will change.'), findsOneWidget);
  });
}

/// A repository whose reorder write fails.
class _FailingReorder extends RuleRepository {
  @override
  Future<void> reorder(List<String> orderedIds) async =>
      throw StateError('disk full');
}

/// A repository whose reorder write fails after a sync renamed Bravo.
class _SyncThenFail extends RuleRepository {
  _SyncThenFail(this.db);

  final AppDatabase db;

  @override
  Future<void> reorder(List<String> orderedIds) async {
    await db.customUpdate(
      "UPDATE rules SET name = 'Charlie' WHERE name = 'Bravo'",
      updates: {db.rules},
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    throw StateError('disk full');
  }
}
