import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
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

/// A plan's start time is clock digits stamped UTC, like the dive log's
/// times (issue #3565), all the way to the dive it is converted to.
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

  final nine = DateTime.utc(2026, 10, 27, 9);

  DivePlanNotifier editor() =>
      container.read(divePlanNotifierProvider.notifier);

  void planStartingAt(DateTime? start) {
    editor().addSimplePlan(maxDepth: 30.0, bottomTimeMinutes: 20);
    final state = container.read(divePlanNotifierProvider);
    editor().loadPlan(state.copyWith(startDateTime: start));
  }

  test('a converted plan dives at its start', () {
    planStartingAt(nine);
    expect(editor().toDive().dateTime, nine);
  });

  test('a converted plan with no start dives at the clock time now', () {
    planStartingAt(null);
    final dive = withClock(
      Clock.fixed(DateTime(2026, 10, 27, 14, 30)),
      () => editor().toDive(),
    );
    expect(dive.dateTime, DateTime.utc(2026, 10, 27, 14, 30));
  });

  test(
    'the converted dive reads back at the start shown in the plan',
    () async {
      planStartingAt(nine);
      final created = await container
          .read(diveRepositoryProvider)
          .createDive(editor().toDive());

      final fetched = await container
          .read(diveRepositoryProvider)
          .getDiveById(created.id);

      expect(fetched!.dateTime, nine);
    },
  );

  test('a saved plan keeps its start', () async {
    planStartingAt(nine);
    await editor().save();
    final id = container.read(divePlanNotifierProvider).id;

    final stored = await container.read(divePlanRepositoryProvider).getPlan(id);

    expect(stored!.startDateTime, nine);
    expect(stored.startDateTime!.isUtc, isTrue);
  });
}
