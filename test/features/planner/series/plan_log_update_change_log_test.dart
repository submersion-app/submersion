import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
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

/// The planner's own "Update planned dives" in the change log: one entry,
/// labelled, whose revert takes the rewritten profile back (issue #4203).
void main() {
  late ProviderContainer c;

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

  Future<List<Object?>> samplesOf(String diveId) async => [
    for (final row
        in await DatabaseService.instance.database
            .customSelect(
              'SELECT samples FROM dive_profile_series WHERE dive_id = ? '
              'ORDER BY id',
              variables: [Variable.withString(diveId)],
            )
            .get())
      row.data['samples'],
  ];

  test('an update is one labelled entry, and its revert brings the old '
      'profile back', () async {
    final id = (await updatePlannedDives(c)).selectedDiveId!;
    final before = await samplesOf(id);

    final bottom = c.read(divePlanNotifierProvider).segments.last;
    c
        .read(divePlanNotifierProvider.notifier)
        .updateSegment(
          bottom.id,
          bottom.copyWith(durationSeconds: bottom.durationSeconds + 600),
        );
    await updatePlannedDives(c);
    expect(await samplesOf(id), isNot(before));

    await ChangeLogRepository().settleAll();
    final newest = await DatabaseService.instance.database
        .customSelect(
          'SELECT id FROM change_log_operations WHERE label = ? '
          'ORDER BY started_at DESC, rowid DESC LIMIT 1',
          variables: [Variable.withString(ChangeLogLabels.updatePlannedDives)],
        )
        .getSingle();

    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await service.execute(
      await service.planOperation(newest.read<String>('id')),
    );

    expect(await samplesOf(id), before);
  });
}
