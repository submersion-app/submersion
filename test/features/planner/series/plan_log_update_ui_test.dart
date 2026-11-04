import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The "Create / Update planned dives" menu item on the plan canvas (issue
/// #3565, phase 2b).
void main() {
  final nine = DateTime.utc(2026, 10, 27, 9);

  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
    ],
    locale: const Locale('en'),
    child: const PlanCanvasPage(),
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

  PlanSeriesNotifier series(WidgetTester tester) =>
      containerOf(tester).read(planSeriesNotifierProvider.notifier);

  Future<void> pumpPlan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    containerOf(tester)
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 18, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
  }

  /// Dives A and B, the second with its tanks filled.
  Future<void> twoDives(WidgetTester tester, {DateTime? start}) async {
    if (start != null) series(tester).setSelectedStart(start);
    series(tester).addDive();
    series(tester).fillAllTanks();
    await tester.pumpAndSettle();
  }

  Future<void> tapMenu(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  /// Lets the database's real IO and the app's timers both run until
  /// [condition] holds.
  Future<void> settleUntil(
    WidgetTester tester,
    bool Function() condition,
  ) async {
    for (var round = 0; round < 200 && !condition(); round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(condition(), isTrue);
  }

  Future<List<String>> loggedIds(WidgetTester tester) async {
    final dives = await tester.runAsync(() => DiveRepository().getAllDives());
    return [for (final dive in dives!) dive.id];
  }

  testWidgets('a series with no start asks for one before writing', (
    tester,
  ) async {
    await pumpPlan(tester);
    await twoDives(tester);

    await tapMenu(tester, 'Create planned dives');

    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await loggedIds(tester), isEmpty);
  });

  testWidgets('a series is added to the log, then offered for update', (
    tester,
  ) async {
    await pumpPlan(tester);
    await twoDives(tester, start: nine);

    await tapMenu(tester, 'Create planned dives');
    await settleUntil(
      tester,
      () => find.byType(SnackBar).evaluate().isNotEmpty,
    );

    expect(find.text('2 planned dives added to the log'), findsOneWidget);
    expect(await loggedIds(tester), hasLength(2));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Update planned dives'), findsOneWidget);
  });

  testWidgets('a removed dive still in the log is offered for deletion', (
    tester,
  ) async {
    await pumpPlan(tester);
    await twoDives(tester, start: nine);
    series(tester).addDive();
    series(tester).fillAllTanks();
    await tester.pumpAndSettle();
    await tapMenu(tester, 'Create planned dives');
    await settleUntil(
      tester,
      () => find.byType(SnackBar).evaluate().isNotEmpty,
    );
    final removed = containerOf(
      tester,
    ).read(planSeriesNotifierProvider).dives[1].state.linkedDiveId;
    series(tester).removeDive(1);
    await tester.pumpAndSettle();

    await tapMenu(tester, 'Update planned dives');
    await settleUntil(
      tester,
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
    );
    expect(find.text('Delete from the log?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await settleUntil(
      tester,
      () =>
          find.text('2 planned dives updated in the log').evaluate().isNotEmpty,
    );

    final left = await loggedIds(tester);
    expect(left, hasLength(2));
    expect(left, isNot(contains(removed)));
  });
}
