import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The trend chart gap threshold (issue #3251) set through the real notifier
/// reaches the diver's stored settings and the chart-facing provider, even
/// when it is made before the settings have loaded (the #998 race).
void main() {
  late ProviderContainer container;
  late String diverId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    );
    diverId = diver.id;
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diverId});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('a pick made before the settings load survives the load', () async {
    final sub = container.listen(trendGapThresholdProvider, (_, _) {});
    addTearDown(sub.close);
    expect(sub.read(), TrendGapThreshold.year1);

    await container
        .read(settingsProvider.notifier)
        .setTrendGapThreshold(TrendGapThreshold.years2);

    expect(sub.read(), TrendGapThreshold.years2);
    final stored = await DiverSettingsRepository().getSettingsForDiver(diverId);
    expect(stored!.trendGapThreshold, TrendGapThreshold.years2);
  });
}
