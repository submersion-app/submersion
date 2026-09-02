import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The lane the gas statistics page shows when the preference displays
/// both. Session only; null follows the preference.
final statisticsGasLaneOverrideProvider = StateProvider<GasConsumptionLane?>(
  (ref) => null,
);

/// The lane every section of the gas statistics page reads, and the one
/// source of truth for which repository pair member the providers call. An
/// override only counts while the preference still allows that lane.
final statisticsGasLaneProvider = Provider<GasConsumptionLane>((ref) {
  final display = ref.watch(gasConsumptionDisplayProvider);
  final override = ref.watch(statisticsGasLaneOverrideProvider);
  if (override != null && display.lanes.contains(override)) return override;
  return display.lanes.first;
});
