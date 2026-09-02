import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1028: personal records on the Statistics tab must follow the tab's
/// filter, the way every other panel on that page already does. The unfiltered
/// [diveRecordsProvider] stays as-is for the dive-log summary widget, which is
/// not a Statistics-tab surface.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> insertDive(String id, {required double maxDepth}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            maxDepth: Value(maxDepth),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  ProviderContainer makeContainer(DiveFilterState filter) => ProviderContainer(
    overrides: [
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      gasModelProvider.overrideWith((ref) => GasModel.real),
      statisticsFilterProvider.overrideWith((ref) => filter),
    ],
  );

  test('filteredDiveRecordsProvider narrows the records to the active '
      'Statistics filter', () async {
    await insertDive('shallow', maxDepth: 10);
    await insertDive('deep', maxDepth: 40);

    final unfilteredContainer = makeContainer(const DiveFilterState());
    addTearDown(unfilteredContainer.dispose);
    final unfiltered = await unfilteredContainer.read(
      filteredDiveRecordsProvider.future,
    );

    // Sanity check: without a filter the deep dive wins, so a filter that
    // excludes it has something real to change.
    expect(unfiltered.deepestDive!.diveId, 'deep');

    final filteredContainer = makeContainer(
      const DiveFilterState(maxDepth: 20),
    );
    addTearDown(filteredContainer.dispose);
    final filtered = await filteredContainer.read(
      filteredDiveRecordsProvider.future,
    );

    expect(
      filtered.deepestDive!.diveId,
      'shallow',
      reason:
          'the deepest dive must come from the filtered subset, otherwise it '
          'contradicts the totals shown directly above it',
    );
    expect(filtered.shallowestDive!.diveId, 'shallow');
    expect(filtered.firstDive!.diveId, 'shallow');
    expect(filtered.lastDive!.diveId, 'shallow');
  });

  test(
    'diveRecordsProvider stays unfiltered for non-Statistics surfaces',
    () async {
      await insertDive('shallow', maxDepth: 10);
      await insertDive('deep', maxDepth: 40);

      final container = makeContainer(const DiveFilterState(maxDepth: 20));
      addTearDown(container.dispose);

      final records = await container.read(diveRecordsProvider.future);

      expect(
        records.deepestDive!.diveId,
        'deep',
        reason:
            'the dive-log summary widget reads diveRecordsProvider and has no '
            'filter UI of its own; the Statistics filter must not reach it',
      );
    },
  );
}
