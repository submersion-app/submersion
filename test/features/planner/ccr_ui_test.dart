import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

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
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  List<dynamic> overrides() => [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
  ];

  testWidgets('badge toggles between OC and CCR', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(overrides: overrides(), child: const PlanCanvasPage()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    expect(find.text('OC'), findsOneWidget);

    await tester.tap(find.text('OC'));
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).mode, domain.PlanMode.ccr);
    expect(find.text('CCR'), findsOneWidget);
  });

  testWidgets('CCR plan with bailout tank shows the bailout section', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: overrides(),
        child: SizedBox(
          width: 500,
          height: 700,
          child: PlanResultsSheet(controller: ScrollController()),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanResultsSheet)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    notifier.updateMode(domain.PlanMode.ccr);
    notifier.addTank(
      const DiveTank(
        id: 'bo',
        volume: 11.1,
        startPressure: 207,
        gasMix: GasMix(o2: 50),
        role: TankRole.bailout,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Bailout'), findsWidgets);
    expect(find.textContaining('Worst case'), findsOneWidget);
    expect(find.textContaining('Required'), findsOneWidget);
  });
}
