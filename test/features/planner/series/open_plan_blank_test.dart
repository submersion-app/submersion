import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
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

/// A repository whose reads wait for [gate], as a slow first read does.
class _GatedSeriesRepository extends DivePlanSeriesRepository {
  _GatedSeriesRepository(this.gate);

  Completer<void> gate;

  @override
  Future<String?> seriesIdForPlan(String planId) async {
    await gate.future;
    return super.seriesIdForPlan(planId);
  }
}

/// A saved plan opened in the planner shows nothing of the plan the editor
/// held before it, only a blank page until it is loaded (issue #3565).
void main() {
  late ProviderContainer c;
  late _GatedSeriesRepository series;

  setUp(() async {
    await setUpTestDatabase();
    series = _GatedSeriesRepository(Completer<void>()..complete());
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  /// A home page with a button pushing the planner on [target], with the
  /// saved plan 'previous' already open in the editor.
  Future<void> pumpHome(WidgetTester tester, String target) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final repository = DivePlanRepository();
      await repository.savePlan(
        divePlanFromState(
          seriesDiveState(id: 'previous').copyWith(name: 'The previous plan'),
        ),
      );
      await repository.savePlan(
        divePlanFromState(
          seriesDiveState(id: 'other').copyWith(name: 'The other plan'),
        ),
      );
    });
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          divePlanSeriesRepositoryProvider.overrideWithValue(series),
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
    await tester.runAsync(() => openSavedPlan(c, 'previous'));
    await tester.pump();
    expect(c.read(divePlanNotifierProvider).name, 'The previous plan');
    series.gate = Completer<void>();
  }

  /// The planner's first frame, before its plan has been read.
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('another plan shows a blank page until it is loaded', (
    tester,
  ) async {
    await pumpHome(tester, 'other');
    await open(tester);

    // Still loading: nothing of the plan the editor held.
    expect(find.byType(PlanCanvasPage), findsOneWidget);
    expect(find.byType(PlanProfileChart), findsNothing);
    expect(find.text('The previous plan'), findsNothing);

    series.gate.complete();
    await settle(tester);

    expect(c.read(divePlanNotifierProvider).id, 'other');
    expect(find.byType(PlanProfileChart), findsOneWidget);
    expect(find.text('The other plan'), findsOneWidget);
  });

  testWidgets('the plan the editor holds shows at once', (tester) async {
    await pumpHome(tester, 'previous');
    await open(tester);

    expect(find.byType(PlanProfileChart), findsOneWidget);
    expect(find.text('The previous plan'), findsOneWidget);
    series.gate.complete();
    await settle(tester);
  });
}
