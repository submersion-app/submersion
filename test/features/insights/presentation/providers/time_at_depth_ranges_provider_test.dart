import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Time at depth is banded in the diver's own depth unit (issue #4600).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<ProviderContainer> containerFor(DepthUnit unit) async {
    final container = ProviderContainer(
      overrides: (await getBaseOverrides(
        settingsNotifier: MockSettingsNotifier(AppSettings(depthUnit: unit)),
      )).cast(),
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Ten minutes held at 15 m, which is 49 ft.
  Future<void> seedDive() async {
    final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('a'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await ProfileSeriesRepository().insertSeries(
      diveId: 'a',
      computerId: null,
      isPrimary: true,
      samples: [
        for (var t = 0; t <= 600; t += 10)
          ProfileSample(timestamp: t, depth: 15.0),
      ],
      now: now,
    );
  }

  test('a metres diver gets 10 m bands', () async {
    await seedDive();
    final container = await containerFor(DepthUnit.meters);

    final ranges = await container.read(timeAtDepthRangesProvider.future);

    expect(ranges, [
      (lowerDepth: 0, upperDepth: 10, minutes: 0),
      (lowerDepth: 10, upperDepth: 20, minutes: 10),
    ]);
  });

  test('a feet diver gets 30 ft bands', () async {
    await seedDive();
    final container = await containerFor(DepthUnit.feet);

    final ranges = await container.read(timeAtDepthRangesProvider.future);

    expect(ranges, [
      (lowerDepth: 0, upperDepth: 30, minutes: 0),
      (lowerDepth: 30, upperDepth: 60, minutes: 10),
    ]);
  });
}
