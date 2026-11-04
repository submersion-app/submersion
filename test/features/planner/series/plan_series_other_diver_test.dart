import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
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

/// Saved plans are open to every profile, so one can open a plan following
/// another diver's logged dive (issue #3565).
void main() {
  late ProviderContainer c;

  setUp(() async {
    await setUpTestDatabase();
    // The active diver's own log, which does not hold the followed dive.
    c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        divesProvider.overrideWith((ref) async => <Dive>[]),
        profileAnalysisProvider.overrideWith((ref, id) async => null),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(c.dispose);

    final database = DatabaseService.instance.database;
    await database
        .into(database.divers)
        .insert(
          const db.DiversCompanion(
            id: Value('owner'),
            name: Value('owner'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await c
        .read(diveRepositoryProvider)
        .createDive(
          Dive(
            id: 'theirs',
            diverId: 'owner',
            diveNumber: 7,
            dateTime: DateTime.utc(2026, 10, 27, 8),
            entryTime: DateTime.utc(2026, 10, 27, 8),
            runtime: const Duration(minutes: 45),
          ),
        );
    c
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 25);
    c.read(planSeriesNotifierProvider);
  });

  tearDown(tearDownTestDatabase);

  test('the follow is found though the dive is another diver\'s', () async {
    final follow = await c.read(seriesFollowProvider('theirs').future);

    expect(follow?.followed.id, 'theirs');
    expect(follow?.followed.diveNumber, 7);
  });

  test('a dive that is gone is still no follow', () async {
    expect(await c.read(seriesFollowProvider('gone').future), isNull);
  });

  test('opening and saving such a plan keeps the follow', () async {
    final follow = await c.read(seriesFollowProvider('theirs').future);
    final series = c.read(planSeriesNotifierProvider.notifier);
    series.followDive(follow!, surfaceInterval: const Duration(hours: 1));
    await saveCurrentSeries(c);
    final planId = c.read(divePlanNotifierProvider).id;
    c.read(divePlanNotifierProvider.notifier).newPlan();

    await openSavedPlan(c, planId);
    expect(c.read(planSeriesNotifierProvider).follow?.followed.id, 'theirs');

    await saveCurrentSeries(c);
    c.read(divePlanNotifierProvider.notifier).newPlan();
    await openSavedPlan(c, planId);

    expect(c.read(planSeriesNotifierProvider).follow?.followed.id, 'theirs');
  });
}
