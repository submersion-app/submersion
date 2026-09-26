import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_gas_lane_provider.dart';

void main() {
  ProviderContainer containerFor(GasConsumptionDisplay display) {
    final container = ProviderContainer(
      overrides: [gasConsumptionDisplayProvider.overrideWithValue(display)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('follows the preference when there is no override', () {
    expect(
      containerFor(GasConsumptionDisplay.rmv).read(insightsGasLaneProvider),
      GasConsumptionLane.rmv,
    );
    expect(
      containerFor(GasConsumptionDisplay.both).read(insightsGasLaneProvider),
      GasConsumptionLane.sac,
    );
  });

  test('honors an override the preference allows', () {
    final container = containerFor(GasConsumptionDisplay.both);
    container.read(insightsGasLaneOverrideProvider.notifier).state =
        GasConsumptionLane.rmv;
    expect(container.read(insightsGasLaneProvider), GasConsumptionLane.rmv);
  });

  test('ignores an override the preference forbids', () {
    final container = containerFor(GasConsumptionDisplay.sac);
    container.read(insightsGasLaneOverrideProvider.notifier).state =
        GasConsumptionLane.rmv;
    expect(container.read(insightsGasLaneProvider), GasConsumptionLane.sac);
  });
}
