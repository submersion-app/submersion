import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/plan_link_actions.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';

void main() {
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
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

  /// A button that runs [action] and records what it returned, so a test can
  /// tap it and walk through any dialog it opens.
  Future<List<bool>> pumpAction(
    WidgetTester tester,
    Future<bool> Function(BuildContext, WidgetRef) action,
  ) async {
    final results = <bool>[];
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        locale: const Locale('en'),
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => results.add(await action(context, ref)),
            child: const Text('go'),
          ),
        ),
      ),
    );
    return results;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('linking a free plan to a free dive asks nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedDive('dive-1');
      await seedPlan('plan-1');
    });
    final results = await pumpAction(
      tester,
      (context, ref) =>
          linkPlanWithConfirm(context, ref, planId: 'plan-1', diveId: 'dive-1'),
    );

    await tester.tap(find.text('go'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(results, [true]);
    final plan = await tester.runAsync(() => repository.getPlan('plan-1'));
    expect(plan!.linkedDiveId, 'dive-1');
  });

  testWidgets('moving a link asks first and cancelling changes nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedDive('dive-1');
      await seedDive('dive-2');
      await seedPlan('plan-1', linkedDiveId: 'dive-1');
    });
    final results = await pumpAction(
      tester,
      (context, ref) =>
          linkPlanWithConfirm(context, ref, planId: 'plan-1', diveId: 'dive-2'),
    );

    await tester.tap(find.text('go'));
    await settle(tester);
    expect(find.text("Move this plan's link?"), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(results, [false]);
    final plan = await tester.runAsync(() => repository.getPlan('plan-1'));
    expect(plan!.linkedDiveId, 'dive-1');
  });

  testWidgets('replacing a dive\'s plan names the plan it clears', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedDive('dive-1');
      await seedPlan('plan-old', linkedDiveId: 'dive-1');
      await seedPlan('plan-new');
    });
    final results = await pumpAction(
      tester,
      (context, ref) => linkPlanWithConfirm(
        context,
        ref,
        planId: 'plan-new',
        diveId: 'dive-1',
      ),
    );

    await tester.tap(find.text('go'));
    await settle(tester);
    expect(find.text("Replace this dive's plan?"), findsOneWidget);
    expect(find.textContaining('Plan plan-old'), findsOneWidget);

    await tester.tap(find.text('Link'));
    await settle(tester);

    expect(results, [true]);
    final old = await tester.runAsync(() => repository.getPlan('plan-old'));
    expect(old!.linkedDiveId, isNull);
  });

  testWidgets('relinking a plan to its own dive asks nothing', (tester) async {
    await tester.runAsync(() async {
      await seedDive('dive-1');
      await seedPlan('plan-1', linkedDiveId: 'dive-1');
    });
    final results = await pumpAction(
      tester,
      (context, ref) =>
          linkPlanWithConfirm(context, ref, planId: 'plan-1', diveId: 'dive-1'),
    );

    await tester.tap(find.text('go'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(results, [true]);
  });

  testWidgets('relinking a plan to its own dive writes nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedDive('dive-1');
      await seedPlan('plan-1', linkedDiveId: 'dive-1');
    });
    final before = await tester.runAsync(() => repository.getPlan('plan-1'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await pumpAction(
      tester,
      (context, ref) =>
          linkPlanWithConfirm(context, ref, planId: 'plan-1', diveId: 'dive-1'),
    );

    await tester.tap(find.text('go'));
    await settle(tester);

    final after = await tester.runAsync(() => repository.getPlan('plan-1'));
    expect(after!.updatedAt, before!.updatedAt);
  });

  testWidgets('the open plan adopts a link written through the action', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedDive('dive-1');
    });
    late String openId;
    final results = await pumpAction(tester, (context, ref) async {
      final notifier = ref.read(divePlanNotifierProvider.notifier);
      await notifier.save();
      openId = ref.read(divePlanNotifierProvider).id;
      if (!context.mounted) return false;
      return linkPlanWithConfirm(
        context,
        ref,
        planId: openId,
        diveId: 'dive-1',
      );
    });

    await tester.tap(find.text('go'));
    await settle(tester);

    expect(results, [true]);
    final container = ProviderScope.containerOf(
      tester.element(find.text('go')),
    );
    expect(container.read(divePlanNotifierProvider).linkedDiveId, 'dive-1');
  });

  testWidgets('unlink asks first and cancelling changes nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedDive('dive-1');
      await seedPlan('plan-1', linkedDiveId: 'dive-1');
    });
    final results = await pumpAction(
      tester,
      (context, ref) => unlinkPlanWithConfirm(context, ref, planId: 'plan-1'),
    );

    await tester.tap(find.text('go'));
    await settle(tester);
    expect(find.text('Unlink this plan?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(results, [false]);
    final kept = await tester.runAsync(() => repository.getPlan('plan-1'));
    expect(kept!.linkedDiveId, 'dive-1');
  });

  testWidgets('confirming unlink clears the link', (tester) async {
    await tester.runAsync(() async {
      await seedDive('dive-1');
      await seedPlan('plan-1', linkedDiveId: 'dive-1');
    });
    final results = await pumpAction(
      tester,
      (context, ref) => unlinkPlanWithConfirm(context, ref, planId: 'plan-1'),
    );

    await tester.tap(find.text('go'));
    await settle(tester);
    await tester.tap(find.text('Unlink'));
    await settle(tester);

    expect(results, [true]);
    final gone = await tester.runAsync(() => repository.getPlan('plan-1'));
    expect(gone!.linkedDiveId, isNull);
  });

  group('planLinkBadge', () {
    final l10n = AppLocalizationsEn();
    const units = UnitFormatter(AppSettings());
    domain.DivePlanSummary summary({
      String? diveId,
      int? number,
      bool isPlanned = false,
      DateTime? date,
    }) => domain.DivePlanSummary(
      id: 'p',
      name: 'Plan',
      updatedAt: DateTime(2026),
      linkedDiveId: diveId,
      linkedDiveNumber: number,
      linkedDiveIsPlanned: isPlanned,
      linkedDiveDate: date,
    );

    test('reads Dived as #N', () {
      expect(
        planLinkBadge(l10n, summary(diveId: 'd', number: 142), units),
        'Dived as #142',
      );
    });

    test('a planned dive reads the waiting line', () {
      expect(
        planLinkBadge(l10n, summary(diveId: 'd', isPlanned: true), units),
        'Waiting for the dive',
      );
    });

    test('an unnumbered dive falls back to its date', () {
      final date = DateTime.utc(2026, 6, 1);
      expect(
        planLinkBadge(l10n, summary(diveId: 'd', date: date), units),
        'Dived ${units.formatDate(date)}',
      );
    });

    test('an unlinked plan has no badge', () {
      expect(planLinkBadge(l10n, summary(), units), isNull);
    });
  });
}
