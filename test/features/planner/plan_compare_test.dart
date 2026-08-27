import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/pages/plan_compare_page.dart';
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

  testWidgets('compare page overlays profiles and lists diff rows', (
    tester,
  ) async {
    // Seed two saved plans through the notifier + repository.
    final seedContainer = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(seedContainer.dispose);
    final notifier = seedContainer.read(divePlanNotifierProvider.notifier);

    notifier.addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    notifier.updateName('Shallow plan');
    final firstId = seedContainer.read(divePlanNotifierProvider).id;
    await notifier.save();

    notifier.newPlan();
    notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    notifier.updateName('Deep plan');
    final secondId = seedContainer.read(divePlanNotifierProvider).id;
    await notifier.save();

    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: PlanComparePage(planIds: [firstId, secondId]),
      ),
    );
    await tester.pumpAndSettle();

    // One profile line per plan.
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));

    // Legend and diff-table header carry both plan names (legend + header).
    expect(find.text('Shallow plan'), findsNWidgets(2));
    expect(find.text('Deep plan'), findsNWidgets(2));
    expect(find.text('TTS'), findsOneWidget);
    expect(find.text('CNS'), findsOneWidget);
  });

  testWidgets('fewer than two resolvable plans shows the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const PlanComparePage(planIds: ['missing-1', 'missing-2']),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('at least two'), findsOneWidget);
  });
}
