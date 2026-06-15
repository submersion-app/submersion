import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

/// Provider for gas switches of a specific dive
/// Returns gas switches with full tank info for display purposes
final gasSwitchesProvider =
    FutureProvider.family<List<GasSwitchWithTank>, String>((ref, diveId) async {
      final repository = ref.watch(diveRepositoryProvider);
      final sub = repository.watchDiveDetailChanges().listen(
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(sub.cancel);
      return repository.getGasSwitchesForDive(diveId);
    });

/// Gas type classification for coloring
enum GasType { air, nitrox, oxygen, trimix }

/// Extension to determine gas type from GasSwitchWithTank
extension GasSwitchWithTankGasType on GasSwitchWithTank {
  GasType get gasType {
    if (isTrimix) return GasType.trimix;
    if (isOxygen) return GasType.oxygen;
    if (isNitrox) return GasType.nitrox;
    return GasType.air;
  }
}

/// Extension to determine gas type from O2/He fractions
extension GasTypeFromFractions on ({double o2, double he}) {
  GasType get gasType {
    if (he > 0) return GasType.trimix;
    if (o2 >= 0.99) return GasType.oxygen;
    if (o2 > 0.22) return GasType.nitrox;
    return GasType.air;
  }
}
