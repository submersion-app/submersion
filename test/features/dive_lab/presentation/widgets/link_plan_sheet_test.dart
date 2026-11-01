import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/link_plan_sheet.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/pump_until.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  domain.DivePlanSummary summary(
    String id,
    DateTime updated, {
    String? linkedDiveId,
    int? linkedDiveNumber,
  }) => domain.DivePlanSummary(
    id: id,
    name: 'Plan $id',
    updatedAt: updated,
    linkedDiveId: linkedDiveId,
    linkedDiveNumber: linkedDiveNumber,
  );

  Future<void> pump(
    WidgetTester tester,
    List<domain.DivePlanSummary> plans, {
    String diveId = 'dive-1',
  }) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divePlanSummariesProvider.overrideWith((ref) async => plans),
        ],
        locale: const Locale('en'),
        child: LinkPlanSheet(diveId: diveId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<String> titles(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      (tile.title! as Text).data!,
  ];

  testWidgets('lists free plans newest first, then linked ones', (
    tester,
  ) async {
    await pump(tester, [
      summary('c', DateTime(2026, 3)),
      summary(
        'b',
        DateTime(2026, 2),
        linkedDiveId: 'other',
        linkedDiveNumber: 9,
      ),
      summary('a', DateTime(2026, 1)),
    ]);

    expect(titles(tester), ['Plan c', 'Plan a', 'Plan b']);
  });

  testWidgets('a linked plan is greyed and says which dive it belongs to', (
    tester,
  ) async {
    await pump(tester, [
      summary(
        'b',
        DateTime(2026, 2),
        linkedDiveId: 'other',
        linkedDiveNumber: 9,
      ),
    ]);

    expect(find.textContaining('Dived as #9'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Plan b'));
    final tile = Theme.of(tester.element(find.byType(ListTile)));
    expect(title.style?.color, tile.colorScheme.outline);
  });

  testWidgets('a short list keeps the sheet short', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divePlanSummariesProvider.overrideWith(
            (ref) async => [summary('a', DateTime(2026))],
          ),
        ],
        locale: const Locale('en'),
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => pickPlanAndLink(context, ref, diveId: 'dive-1'),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Plan a'), findsOneWidget);
    expect(tester.getSize(find.byType(LinkPlanSheet)).height, lessThan(300));
  });

  testWidgets('says so when no plans are saved', (tester) async {
    await pump(tester, const []);

    expect(find.text('No saved plans yet'), findsOneWidget);
  });

  group('picking', () {
    late AppDatabase db;
    late DivePlanRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DivePlanRepository();
    });
    tearDown(tearDownTestDatabase);

    Future<void> seedDive(String id) => db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: const Value(1000),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ),
        );

    Future<void> seedPlan(String id, {String? linkedDiveId}) =>
        repository.savePlan(
          domain.DivePlan(
            id: id,
            name: 'Plan $id',
            gfLow: 30,
            gfHigh: 70,
            linkedDiveId: linkedDiveId,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );

    /// What the pick returned, filled when the link has landed. Waiting on
    /// this rather than reading the plan: the write runs in a transaction the
    /// test's frames drive, so a read awaited meanwhile would never return.
    late List<bool> results;

    Future<void> openSheet(WidgetTester tester) async {
      results = [];
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          ],
          locale: const Locale('en'),
          child: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async => results.add(
                await pickPlanAndLink(context, ref, diveId: 'dive-1'),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await pumpUntilRealAsync(
        tester,
        () => find.text('Plan plan-1').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('picking a free plan links it', (tester) async {
      await tester.runAsync(() async {
        await seedDive('dive-1');
        await seedPlan('plan-1');
      });

      await openSheet(tester);
      await tester.tap(find.text('Plan plan-1'));
      await pumpUntilRealAsync(tester, () => results.isNotEmpty);

      expect(results, [true]);
      final plan = await tester.runAsync(() => repository.getPlan('plan-1'));
      expect(plan!.linkedDiveId, 'dive-1');
    });

    testWidgets('picking a linked plan confirms the move', (tester) async {
      await tester.runAsync(() async {
        await seedDive('dive-1');
        await seedDive('dive-2');
        await seedPlan('plan-1', linkedDiveId: 'dive-2');
      });

      await openSheet(tester);
      await tester.tap(find.text('Plan plan-1'));
      await pumpUntilRealAsync(
        tester,
        () => find.byType(AlertDialog).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.text("Move this plan's link?"), findsOneWidget);

      await tester.tap(find.text('Link'));
      await pumpUntilRealAsync(tester, () => results.isNotEmpty);

      final plan = await tester.runAsync(() => repository.getPlan('plan-1'));
      expect(plan!.linkedDiveId, 'dive-1');
    });
  });
}
