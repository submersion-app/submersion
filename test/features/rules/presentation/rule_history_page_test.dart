import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/pages/rule_history_page.dart';
import 'package:submersion/features/rules/presentation/pages/rule_run_page.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';
import 'rules_test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd35', maxDepth: 35, waterType: 'fresh');
    await seedRuleDive(db, 'd40', maxDepth: 40, waterType: 'fresh');
  });
  tearDown(tearDownTestDatabase);

  Future<String> runSalt(RuleRunTrigger trigger, {String? source}) async {
    final repo = RuleRepository();
    final all = await repo.getAll(
      subject: RuleSubject.dives,
      diverId: 'me',
      names: NameIndex(const []),
    );
    if (all.isEmpty) {
      await repo.create(
        diverId: 'me',
        subject: RuleSubject.dives,
        name: 'Salty',
        triggers: const {
          RuleTrigger.afterImport,
          RuleTrigger.afterManualCreate,
        },
        condition: depthOver(30),
        actions: const [
          SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
        ],
      );
    }
    await db.customStatement("UPDATE dives SET water_type = 'fresh'");
    final r =
        await RuleEngine(
          names: () async => NameIndex(const []),
          deviceLabel: () async => 'MacBook',
        ).run(
          RuleRunRequest(
            diverId: 'me',
            trigger: trigger,
            sourceLabel: source,
            targets: const {RuleSubject.dives: null},
          ),
        );
    return r.runId!;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<List<String>> pumpHistory(WidgetTester tester) async {
    final pushed = await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/rules/history',
        home: (_) => const RuleHistoryPage(),
      ),
    );
    await settle(tester);
    return pushed!;
  }

  testWidgets('lists runs newest first with what started them', (tester) async {
    await tester.runAsync(() async {
      await runSalt(RuleRunTrigger.imported, source: 'Perdix 2');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await runSalt(RuleRunTrigger.onDemandAll);
    });
    await pumpHistory(tester);
    expect(find.text('Run by hand on everything'), findsOneWidget);
    expect(find.text('After import (Perdix 2)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Run by hand on everything')).dy,
      lessThan(tester.getTopLeft(find.text('After import (Perdix 2)')).dy),
    );
    expect(find.textContaining('2 items changed by Salty'), findsNWidgets(2));
    expect(find.textContaining('on MacBook'), findsNWidgets(2));
  });

  testWidgets('Undo marks the run undone and reports skipped edits', (
    tester,
  ) async {
    late String run;
    await tester.runAsync(() async {
      run = await runSalt(RuleRunTrigger.imported);
      await db.customStatement(
        "UPDATE dives SET water_type = 'brackish' WHERE id = 'd35'",
      );
    });
    await pumpHistory(tester);
    await tester.tap(find.byTooltip('Undo this run'));
    await settle(tester);
    expect(
      find.textContaining('1 item was edited after this run'),
      findsOneWidget,
    );
    expect(find.textContaining('Undone '), findsOneWidget);
    final r = await tester.runAsync(() => RuleRunRepository().getRun(run));
    expect(r!.isUndone, isTrue);
  });

  testWidgets('nothing undoable yet keeps Undo available', (tester) async {
    await tester.runAsync(() async {
      await runSalt(RuleRunTrigger.imported);
      await db.customStatement("UPDATE dives SET water_type = 'brackish'");
    });
    await pumpHistory(tester);
    await tester.tap(find.byTooltip('Undo this run'));
    await settle(tester);
    expect(
      find.textContaining('Nothing to undo on this device yet'),
      findsOneWidget,
    );
    expect(find.byTooltip('Undo this run'), findsOneWidget);
  });

  testWidgets('tapping a run opens its change list', (tester) async {
    late String run;
    await tester.runAsync(() async {
      run = await runSalt(RuleRunTrigger.imported);
    });
    final pushed = await pumpHistory(tester);
    await tester.tap(find.text('After import'));
    await tester.pumpAndSettle();
    expect(pushed, ['/rules/history/$run']);
  });

  testWidgets('the run page lists the changes and undoes them', (tester) async {
    late String run;
    await tester.runAsync(() async {
      run = await runSalt(RuleRunTrigger.imported);
    });
    await tester.runAsync(
      () => pumpRulesApp(
        tester,
        path: '/rules/history/x',
        home: (_) => RuleRunPage(runId: run),
      ),
    );
    await settle(tester);
    expect(
      find.text('Salty: water type Fresh Water → Salt Water'),
      findsNWidgets(2),
    );
    await tester.tap(find.text('Undo this run'));
    await settle(tester);
    expect(find.text('Undone.'), findsOneWidget);
  });

  testWidgets('Clear history removes every run after confirming', (
    tester,
  ) async {
    await tester.runAsync(() => runSalt(RuleRunTrigger.imported));
    await pumpHistory(tester);
    await tester.tap(find.byKey(const ValueKey('rules_history_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear history'));
    await settle(tester);
    expect(find.textContaining('Each time your rules change'), findsOneWidget);
  });
}
