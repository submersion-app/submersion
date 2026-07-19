import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/planner/presentation/panes/plan_editor_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_results_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final overrides = [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
  ];

  testWidgets('PlanStatTile shows label and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlanStatTile(label: 'Runtime', value: "46'"),
        ),
      ),
    );
    expect(find.text('RUNTIME'), findsOneWidget);
    expect(find.text("46'"), findsOneWidget);
  });

  testWidgets('editor pane stacks segments, tanks, setup', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SizedBox(width: 320, child: PlanEditorPane()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SegmentList), findsOneWidget);
    expect(find.byType(PlanTankList), findsOneWidget);
    expect(find.byType(PlanSetupAccordion), findsOneWidget);
  });

  testWidgets('results pane shows stat tiles reflecting the outcome', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: SizedBox(
          width: 340,
          height: 700,
          child: PlanResultsPane(controller: controller),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanResultsPane)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();
    expect(find.byType(PlanStatTile), findsNWidgets(4));
    expect(find.text('RUNTIME'), findsOneWidget);
  });
}
