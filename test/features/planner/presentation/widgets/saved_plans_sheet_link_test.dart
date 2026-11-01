import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/link_dive_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/pump_until.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  Future<void> pump(WidgetTester tester, DivePlanSummary summary) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divePlanSummariesProvider.overrideWith((ref) async => [summary]),
          divesProvider.overrideWith((ref) async => <Dive>[]),
        ],
        locale: const Locale('en'),
        child: const SavedPlansSheet(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  DivePlanSummary plan({String? linkedDiveId, int? linkedDiveNumber}) =>
      DivePlanSummary(
        id: 'p1',
        name: 'Wreck',
        updatedAt: DateTime(2026, 7, 4),
        linkedDiveId: linkedDiveId,
        linkedDiveNumber: linkedDiveNumber,
      );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
  }

  testWidgets('an unlinked row offers Link to a logged dive', (tester) async {
    await pump(tester, plan());
    await openMenu(tester);

    expect(find.text('Link to a logged dive'), findsOneWidget);
    expect(find.text('Unlink dive'), findsNothing);
    expect(find.text('Change linked dive'), findsNothing);
  });

  testWidgets('a linked row offers Change and Unlink', (tester) async {
    await pump(tester, plan(linkedDiveId: 'd', linkedDiveNumber: 12));
    await openMenu(tester);

    expect(find.text('Change linked dive'), findsOneWidget);
    expect(find.text('Unlink dive'), findsOneWidget);
    expect(find.text('Link to a logged dive'), findsNothing);
  });

  group('the row actions', () {
    late DivePlanRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DivePlanRepository();
    });
    tearDown(tearDownTestDatabase);

    testWidgets('Link to a logged dive opens the picker', (tester) async {
      await tester.runAsync(
        () => repository.savePlan(
          domain.DivePlan(
            id: 'p1',
            name: 'Wreck',
            gfLow: 30,
            gfHigh: 70,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );
      await pump(tester, plan());
      await openMenu(tester);

      await tester.tap(find.text('Link to a logged dive'));
      await pumpUntilRealAsync(
        tester,
        () => find.byType(LinkDiveSheet).evaluate().isNotEmpty,
      );
    });

    testWidgets('Unlink dive asks first', (tester) async {
      await pump(tester, plan(linkedDiveId: 'd', linkedDiveNumber: 12));
      await openMenu(tester);

      await tester.tap(find.text('Unlink dive'));
      await tester.pumpAndSettle();

      expect(find.text('Unlink this plan?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a linked row shows its badge', (tester) async {
    await pump(tester, plan(linkedDiveId: 'd', linkedDiveNumber: 12));

    expect(find.text('Dived as #12'), findsOneWidget);
  });

  testWidgets('an unlinked row shows no badge', (tester) async {
    await pump(tester, plan());

    expect(find.textContaining('Dived as'), findsNothing);
  });
}
