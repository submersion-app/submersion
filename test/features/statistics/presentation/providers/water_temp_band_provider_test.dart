import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1827: the water-temperature bands follow the active diver's
/// temperature unit, and switching the unit re-bins the chart.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('re-bins in the diver unit when the unit setting changes', () async {
    final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;
    // 18.0 C is 64.4 F: 18-24 in Celsius, 50-65 in Fahrenheit.
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('a'),
            diveDateTime: Value(now),
            waterTemp: const Value(18.0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    final settings = MockSettingsNotifier();
    final container = ProviderContainer(
      overrides: (await getBaseOverrides(settingsNotifier: settings)).cast(),
    );
    addTearDown(container.dispose);
    // Keep the provider subscribed so a settings change invalidates it.
    container.listen(waterTempBandDistributionProvider, (_, _) {});

    final celsius = await container.read(
      waterTempBandDistributionProvider.future,
    );
    expect(celsius.map((b) => b.upper), [10, 18, 24, null]);
    expect(celsius.map((b) => b.count), [0, 0, 1, 0]);

    await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);

    final fahrenheit = await container.read(
      waterTempBandDistributionProvider.future,
    );
    expect(fahrenheit.map((b) => b.upper), [50, 65, 75, null]);
    expect(fahrenheit.map((b) => b.count), [0, 1, 0, 0]);
  });
}
