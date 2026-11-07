import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_state.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
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

/// Whether the plan's dives are in the log, and whether the log is behind
/// the plan: the "Create / Update planned dives" menu item's wording and
/// whether it is enabled (issue #3565, phase 2b).
void main() {
  late ProviderContainer c;
  final nine = DateTime.utc(2026, 10, 27, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(c.dispose);
    c
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 18, bottomTimeMinutes: 20);
    c.read(planSeriesNotifierProvider);
  });

  tearDown(tearDownTestDatabase);

  PlanSeriesNotifier series() => c.read(planSeriesNotifierProvider.notifier);

  void twoDives() {
    series().setSelectedStart(nine);
    series().renameSelected('Wreck');
    series().addDive();
    series().fillAllTanks();
  }

  Future<PlannedDivesLogState> logState() async {
    // Keeps the provider alive across the reads, as the page's watch does.
    final sub = c.listen(plannedDivesLogStateProvider, (_, _) {});
    addTearDown(sub.close);
    // Lets the table-change streams fire and the provider settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return c.read(plannedDivesLogStateProvider.future);
  }

  test('a plan not in the log offers to create its dives', () async {
    twoDives();

    final state = await logState();

    expect(state.entriesExist, isFalse);
    expect(state.outOfDate, isTrue);
  });

  test('right after the log is updated there is nothing to update', () async {
    twoDives();
    await updatePlannedDives(c);

    final state = await logState();

    expect(state.entriesExist, isTrue);
    expect(state.outOfDate, isFalse);
  });

  test('a series reopened from its save is still up to date', () async {
    twoDives();
    await updatePlannedDives(c);
    final planId = c.read(planSeriesNotifierProvider).dives[1].state.id;

    c.read(divePlanNotifierProvider.notifier).newPlan();
    await openSavedPlan(c, planId);
    expect(c.read(planSeriesNotifierProvider).dives, hasLength(2));

    final state = await logState();
    expect(state.entriesExist, isTrue);
    expect(state.outOfDate, isFalse);
  });

  test('a single plan updated is up to date too', () async {
    series().setSelectedStart(nine);
    await updatePlannedDives(c);

    final state = await logState();

    expect(state.entriesExist, isTrue);
    expect(state.outOfDate, isFalse);
  });

  group('the log falls behind when', () {
    setUp(() async {
      twoDives();
      await updatePlannedDives(c);
      expect((await logState()).outOfDate, isFalse);
    });

    test('a dive is edited, saved or not', () async {
      c
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 24, bottomTimeMinutes: 25);

      expect((await logState()).outOfDate, isTrue);
    });

    test('a dive is renamed', () async {
      series().renameSelected('Night dive');

      expect((await logState()).outOfDate, isTrue);
    });

    test('the series starts at another time', () async {
      series().select(0);
      series().setSelectedStart(nine.add(const Duration(hours: 1)));

      expect((await logState()).outOfDate, isTrue);
    });

    test('a dive is added that has no entry yet', () async {
      series().addDive();
      series().fillAllTanks();

      final state = await logState();
      expect(state.entriesExist, isTrue);
      expect(state.outOfDate, isTrue);
    });

    test('an entry is edited in the log', () async {
      final id = c.read(planSeriesNotifierProvider).dives[0].state.linkedDiveId;
      final repository = c.read(diveRepositoryProvider);
      final entry = await repository.getDiveById(id!);
      await repository.updateDive(entry!.copyWith(notes: 'Changed in the log'));

      expect((await logState()).outOfDate, isTrue);
    });

    test('a dive with a planned entry is removed from the series', () async {
      // The last of three: the others are unchanged, but its entry is still
      // to be offered for deletion.
      series().addDive();
      series().fillAllTanks();
      await updatePlannedDives(c);
      expect((await logState()).outOfDate, isFalse);
      series().removeDive(2);

      final state = await logState();
      expect(state.entriesExist, isTrue);
      expect(state.outOfDate, isTrue);
    });

    test('an entry is deleted from the log', () async {
      final id = c.read(planSeriesNotifierProvider).dives[1].state.linkedDiveId;
      await c.read(diveRepositoryProvider).deleteDive(id!);

      expect((await logState()).outOfDate, isTrue);
    });
  });

  test('a series whose dives have all been dived has nothing to do', () async {
    twoDives();
    await updatePlannedDives(c);
    final repository = c.read(diveRepositoryProvider);
    for (final dive in c.read(planSeriesNotifierProvider).dives) {
      final entry = await repository.getDiveById(dive.state.linkedDiveId!);
      await repository.updateDive(entry!.copyWith(isPlanned: false));
    }

    final state = await logState();
    expect(state.entriesExist, isFalse);
    expect(state.outOfDate, isFalse);
  });
}
