import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/pages/rule_edit_page.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';
import 'rules_test_app.dart';

/// The rule editor on the shared Cancel and Save bar (issue #4527, phase 4,
/// plan 4).
void main() {
  late AppDatabase db;
  late RuleRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me', 'b']);
    repo = RuleRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<String> stored({QueryNode? condition}) => repo.create(
    diverId: 'me',
    subject: RuleSubject.dives,
    name: 'Deep',
    triggers: const {RuleTrigger.afterImport},
    condition: condition ?? depthOver(30),
    actions: const [kAddDeepType, AppendDiveNotesAction('deep')],
  );

  Future<RuleRow?> row(String id) =>
      (db.select(db.rules)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// The editor pushed over a stand-in rules list, on routes with the app's
  /// leave check, as the app's are.
  Future<void> pump(
    WidgetTester tester, {
    String? ruleId,
    Future<void> Function()? beforeOpen,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/rules',
      routes: [
        GoRoute(
          path: '/rules',
          builder: (_, _) => const Scaffold(body: Text('LIST')),
        ),
        GoRoute(
          path: '/rules/new',
          onExit: confirmLeaveRecordSitting,
          builder: (_, _) => const RuleEditPage(),
        ),
        GoRoute(
          path: '/rules/:id',
          onExit: confirmLeaveRecordSitting,
          builder: (_, state) =>
              RuleEditPage(ruleId: state.pathParameters['id']),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => ref.watch(currentDiverIdProvider),
          ),
          queryNameIndexProvider.overrideWith((ref) async => kRuleTestNames),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('me');
    await tester.pumpAndSettle();
    if (beforeOpen != null) await tester.runAsync(beforeOpen);
    unawaited(router.push(ruleId == null ? '/rules/new' : '/rules/$ruleId'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Finder saveFinder() => find.widgetWithText(AppBarTextAction, 'Save');

  AppBarTextAction save(WidgetTester tester) =>
      tester.widget<AppBarTextAction>(saveFinder());

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(saveFinder());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> rename(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const ValueKey('rule_name')), name);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
  }

  Finder conditionField() => find.descendant(
    of: find.byKey(const ValueKey('rule_condition_dives')),
    matching: find.byType(TextField),
  );

  Future<List<String?>> sittingLabels() async {
    final rows = await db
        .customSelect(
          "SELECT label FROM change_log_operations "
          "WHERE label LIKE 'record_edit:%'",
        )
        .get();
    return [for (final row in rows) row.read<String?>('label')];
  }

  testWidgets('the bar is the tinted Cancel and Save bar with no back arrow', (
    tester,
  ) async {
    await pump(tester, ruleId: await stored());

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(save(tester).onPressed, isNull);
  });

  testWidgets('a stored rule opened and left alone is unchanged', (
    tester,
  ) async {
    await pump(tester, ruleId: await stored());

    expect(save(tester).onPressed, isNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a rule whose condition did not load is unchanged when left '
      'alone', (tester) async {
    final id = await stored(
      condition: ConditionNode(
        FieldPath(const ['site']),
        QueryOp.eq,
        const RefValue('nowhere', 'Nowhere'),
      ),
    );
    await pump(tester, ruleId: id);

    expect(
      find.text(
        'The condition names something that was deleted. Edit the rule to '
        'run it.',
      ),
      findsOneWidget,
    );
    expect(save(tester).onPressed, isNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a condition typed into a rule with none stored and cleared '
      'again is no change', (tester) async {
    // The rule loads with a problem (its actions cannot be read) but has no
    // stored condition: an empty condition is what it had.
    final id = await stored();
    await db.customStatement(
      "UPDATE rules SET condition_json = '', actions_json = 'not json' "
      "WHERE id = '$id'",
    );
    await pump(tester, ruleId: id);
    expect(
      find.text("This rule's condition can't be read. Edit or delete it."),
      findsOneWidget,
    );

    await tester.enterText(conditionField(), 'depth > 10');
    await tester.pumpAndSettle();
    await tester.enterText(conditionField(), '');
    await tester.pumpAndSettle();

    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a new rule with nothing entered closes on Cancel at once', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('removing an action and putting it back is no change', (
    tester,
  ) async {
    final id = await stored();
    await repo.patch(id, (
      name: null,
      triggers: null,
      condition: null,
      actions: const [kAddDeepType],
    ));
    await pump(tester, ruleId: id);
    final rule = (await repo.getById(id, names: kRuleTestNames))!;
    expect(rule.actions, const [kAddDeepType]);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('rule_action_0')),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add at least one action.'), findsOneWidget);
    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    // The same action again, through the picker.
    await tester.ensureVisible(find.byKey(const ValueKey('rule_add_action')));
    await tester.tap(find.byKey(const ValueKey('rule_add_action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rule_action_search')),
      'Add dive types',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add dive types').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deep').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Add dive types: Deep'), findsOneWidget);

    expect(save(tester).onPressed, isNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a condition that does not parse is a change', (tester) async {
    await pump(tester, ruleId: await stored());

    await tester.enterText(conditionField(), 'depth >');
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Save stays disabled until the rule has a name and an action', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, ruleId: id);

    await rename(tester, '   ');
    expect(save(tester).onPressed, isNull);
    await rename(tester, 'Deeper');
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('Back after renaming asks; Discard leaves the list', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, ruleId: id);
    await rename(tester, 'Deeper');

    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
    expect((await row(id))!.name, 'Deep');
  });

  testWidgets('Save writes one change log operation labelled with the rule', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, ruleId: id);
    await rename(tester, 'Deeper');

    await tapSave(tester);

    expect(find.text('LIST'), findsOneWidget);
    expect((await row(id))!.name, 'Deeper');
    final labels = await sittingLabels();
    expect(labels, hasLength(1));
    final label = RecordEditLabel.decode(labels.single!)!;
    expect(label.table, 'rules');
    expect(label.id, id);
  });

  testWidgets('a new rule is created under the page id', (tester) async {
    await pump(tester);
    await rename(tester, 'Notes');
    final state = tester.state<State>(find.byType(RuleEditPage));
    final pageId = (state as dynamic).newEditorRecordId as String;
    await tester.ensureVisible(find.byKey(const ValueKey('rule_add_action')));
    await tester.tap(find.byKey(const ValueKey('rule_add_action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rule_action_search')),
      'Append to notes',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Append to notes').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rule_value_append')),
      'Boat dive',
    );
    await tester.tap(find.byKey(const ValueKey('rule_action_ok')));
    await tester.pumpAndSettle();

    await tapSave(tester);

    final created = await row(pageId);
    expect(created, isNotNull);
    expect(created!.diverId, 'me');
    expect(created.name, 'Notes');
  });

  testWidgets('a rename keeps the enabled switch flipped meanwhile', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, ruleId: id);
    final actionsBefore = (await row(id))!.actionsJson;
    await repo.setEnabled(id, false);

    await rename(tester, 'Deeper');
    await tapSave(tester);

    final after = (await row(id))!;
    expect(after.name, 'Deeper');
    expect(after.enabled, isFalse);
    expect(after.actionsJson, actionsBefore);
  });

  testWidgets('a rule already loaded as the page opens is filled once', (
    tester,
  ) async {
    final id = await stored();
    // The rule is held loaded before the editor opens, so its first value
    // reaches the editor at once.
    late ProviderSubscription<Object?> held;
    Future<void> holdRule() async {
      held = container.listen(ruleByIdProvider(id), (_, _) {});
      await container.read(ruleByIdProvider(id).future);
    }

    await pump(tester, ruleId: id, beforeOpen: holdRule);
    addTearDown(() => held.close());
    await rename(tester, 'Deeper');

    // A write to the rules table (the list's switch, a sync) ticks the rule.
    await repo.setEnabled(id, false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Deeper'), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('a condition that did not load can be cleared to match every '
      'dive', (tester) async {
    const broken =
        '{"version":1,"node":{"t":"cond","path":["noSuchField"],'
        '"op":"eq","value":{"k":"str","v":"x"}}}';
    final id = await stored();
    await db.customStatement(
      "UPDATE rules SET condition_json = '$broken' WHERE id = '$id'",
    );
    await pump(tester, ruleId: id);
    expect(save(tester).onPressed, isNull);

    await tester.enterText(conditionField(), 'depth > 10');
    await tester.pumpAndSettle();
    await tester.enterText(conditionField(), '');
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNotNull);
    await tapSave(tester);

    expect((await row(id))!.conditionJson, encodeRuleCondition(null));
  });

  testWidgets('a rule deleted while open is refused at Save', (tester) async {
    final id = await stored();
    await pump(tester, ruleId: id);
    await repo.delete(id);

    await rename(tester, 'Deeper');
    await tapSave(tester);

    expect(find.text('This rule no longer exists.'), findsOneWidget);
    expect(await row(id), isNull);
    expect(find.byType(RecordEditBar), findsOneWidget);
  });

  testWidgets('a rule from a newer version opens with a plain bar and no '
      'Save', (tester) async {
    final id = await stored();
    await db.customStatement(
      "UPDATE rules SET actions_json = '{\"version\":9,\"actions\":[]}' "
      "WHERE id = '$id'",
    );
    final before = await row(id);
    await pump(tester, ruleId: id);

    expect(find.textContaining('Made by a newer version'), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(saveFinder(), findsNothing);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
    expect(await row(id), before);
  });

  testWidgets('a new rule typed in closes on a diver switch, writing '
      'nothing', (tester) async {
    await pump(tester);
    await rename(tester, 'Half typed');

    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
    expect(await db.select(db.rules).get(), isEmpty);
  });

  testWidgets('a rule that will not load keeps the error text under a plain '
      'bar', (tester) async {
    await pump(tester, ruleId: 'missing');

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Edit rule'), findsOneWidget);
  });
}
