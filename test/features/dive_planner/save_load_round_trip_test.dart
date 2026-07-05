import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  test('save, reset, and load restores the planner state', () async {
    final notifier = container.read(divePlanNotifierProvider.notifier);

    notifier.addSimplePlan(maxDepth: 30.0, bottomTimeMinutes: 20);
    notifier.updateName('Round trip plan');
    notifier.updateSacRate(17.5);
    final savedId = container.read(divePlanNotifierProvider).id;
    final savedSegmentCount = container
        .read(divePlanNotifierProvider)
        .segments
        .length;
    expect(savedSegmentCount, greaterThan(0));

    await notifier.save(
      summary: const PlanSummaryData(
        maxDepth: 30.0,
        runtimeSeconds: 30 * 60,
        ttsSeconds: 4 * 60,
      ),
    );
    expect(container.read(divePlanNotifierProvider).isDirty, isFalse);

    // The summaries list sees the saved plan.
    final summaries = await container.read(divePlanSummariesProvider.future);
    expect(summaries.map((s) => s.id), contains(savedId));
    expect(
      summaries.firstWhere((s) => s.id == savedId).name,
      'Round trip plan',
    );

    // Reset, then load back by id.
    notifier.newPlan();
    expect(container.read(divePlanNotifierProvider).id, isNot(savedId));

    final loaded = await notifier.loadPlanById(savedId);
    expect(loaded, isTrue);
    final restored = container.read(divePlanNotifierProvider);
    expect(restored.id, savedId);
    expect(restored.name, 'Round trip plan');
    expect(restored.sacRate, 17.5);
    expect(restored.segments, hasLength(savedSegmentCount));
    expect(restored.isDirty, isFalse);
  });

  test('loadPlanById returns false for an unknown id', () async {
    final notifier = container.read(divePlanNotifierProvider.notifier);
    expect(await notifier.loadPlanById('nope'), isFalse);
  });
}
