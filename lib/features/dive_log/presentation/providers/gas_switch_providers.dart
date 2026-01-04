import 'package:submersion/core/providers/provider.dart';

import '../../domain/entities/gas_switch.dart';
import 'dive_providers.dart';

/// Provider for gas switches of a specific dive
/// Returns gas switches with full tank info for display purposes
final gasSwitchesProvider =
    FutureProvider.family<List<GasSwitchWithTank>, String>((ref, diveId) async {
      final repository = ref.watch(diveRepositoryProvider);
      return repository.getGasSwitchesForDive(diveId);
    });

/// Gas type classification for coloring
enum GasType { air, nitrox, trimix }

/// Extension to determine gas type from GasSwitchWithTank
extension GasSwitchWithTankGasType on GasSwitchWithTank {
  GasType get gasType {
    if (isTrimix) return GasType.trimix;
    if (isNitrox) return GasType.nitrox;
    return GasType.air;
  }
}

/// Extension to determine gas type from O2/He fractions
extension GasTypeFromFractions on ({double o2, double he}) {
  GasType get gasType {
    if (he > 0) return GasType.trimix;
    if (o2 > 0.22) return GasType.nitrox;
    return GasType.air;
  }
}
