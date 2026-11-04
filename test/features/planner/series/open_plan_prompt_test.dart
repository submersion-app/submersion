import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';
import 'series_fixtures.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Opening a different saved plan over unsaved changes (issue #3565).
void main() {
  late ProviderContainer c;

  /// The saved plan the button opens.
  var target = 'other';

  setUp(() async {
    target = 'other';
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  /// A home page with a button pushing the planner on the saved plan [target],
  /// and an edited plan of the caller's making already in the editor.
  Future<void> pumpHome(WidgetTester tester, void Function() prepare) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => DivePlanRepository().savePlan(
        divePlanFromState(
          seriesDiveState(id: 'other').copyWith(name: 'The other plan'),
        ),
      ),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanCanvasPage(planId: target),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    c = ProviderScope.containerOf(tester.element(find.text('open')));
    c.read(planSeriesNotifierProvider);
    prepare();
    await tester.pump();
  }

  void editDive() => c
      .read(divePlanNotifierProvider.notifier)
      .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);

  void editSeries() {
    editDive();
    c.read(planSeriesNotifierProvider.notifier).addDive();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('nothing unsaved opens it without asking', (tester) async {
    await pumpHome(tester, () {});
    await open(tester);
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(c.read(divePlanNotifierProvider).id, 'other');
  });

  testWidgets('an edited dive asks to save the dive', (tester) async {
    await pumpHome(tester, editDive);
    await open(tester);

    expect(find.text('Save this dive?'), findsOneWidget);
  });

  testWidgets('an edited series asks to save the series', (tester) async {
    await pumpHome(tester, editSeries);
    await open(tester);

    expect(find.text('Save this series?'), findsOneWidget);
  });

  testWidgets('Cancel keeps the plan and backs out', (tester) async {
    await pumpHome(tester, editDive);
    final before = c.read(divePlanNotifierProvider).id;
    await open(tester);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.byType(PlanCanvasPage), findsNothing);
    expect(c.read(divePlanNotifierProvider).id, before);
    expect(c.read(divePlanNotifierProvider).isDirty, isTrue);
  });

  testWidgets('Discard opens the other plan', (tester) async {
    await pumpHome(tester, editSeries);
    await open(tester);

    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(c.read(divePlanNotifierProvider).id, 'other');
    expect(c.read(planSeriesNotifierProvider).isSeries, isFalse);
  });

  testWidgets('Save on a saved plan keeps it and opens the other', (
    tester,
  ) async {
    late String saved;
    await pumpHome(tester, editDive);
    await tester.runAsync(() async {
      await c.read(divePlanNotifierProvider.notifier).save();
    });
    saved = c.read(divePlanNotifierProvider).id;
    c.read(divePlanNotifierProvider.notifier).updateGradientFactors(33, 77);
    await tester.pump();

    await open(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(c.read(divePlanNotifierProvider).id, 'other');
    final stored = await tester.runAsync(
      () => DivePlanRepository().getPlan(saved),
    );
    expect(stored?.gfLow, 33);
  });

  testWidgets('a dive of the series being edited is selected, edits kept', (
    tester,
  ) async {
    await pumpHome(tester, () {
      editSeries();
      target = c.read(planSeriesNotifierProvider).dives.first.state.id;
    });
    await open(tester);
    await settle(tester);

    final series = c.read(planSeriesNotifierProvider);
    expect(find.byType(AlertDialog), findsNothing);
    expect(series.dives, hasLength(2));
    expect(series.selectedIndex, 0);
    expect(series.isDirty, isTrue);
  });
}
