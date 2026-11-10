import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/data_quality/domain/detectors/missing_gas_switches.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The gas switches a dive's recorded cylinder pressures show, whatever it
/// logged ([inferredGasSwitches], issue #4335), for the switch editor to
/// offer in one tap. Null for a dive that is not open circuit, or gone.
/// Derived here so typing in the dive edit form does not run the detector
/// again, as with the time chips' `cylinderBreathStartsProvider`.
final detectedGasSwitchesProvider = FutureProvider.autoDispose
    .family<MissedSwitches?, String>((ref, diveId) async {
      final ppO2MaxBar = ref.watch(ppO2MaxDecoProvider);
      final dive = await ref.watch(diveProvider(diveId).future);
      if (dive == null || dive.diveMode != DiveMode.oc) return null;
      final pressures = await ref.watch(tankPressuresProvider(diveId).future);
      final profile = [...dive.profile]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return inferredGasSwitches(
        tanks: dive.tanks,
        pressuresByTankId: {
          for (final MapEntry(key: tankId, value: series) in pressures.entries)
            tankId: [
              for (final point in series)
                QualityPressureSample(t: point.timestamp, bar: point.pressure),
            ],
        },
        samples: [
          for (final point in profile)
            QualitySample(t: point.timestamp, depth: point.depth),
        ],
        ppO2MaxBar: ppO2MaxBar,
        environment: dive.environment,
      );
    });
