import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/services/cylinder_breath_starts.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// When each of a dive's cylinders started being breathed, keyed by tank id,
/// with a cylinder that shows no start left out (issue #4089). Derived here
/// so typing in the dive edit form does not run the detector again. Reads the
/// recorded series only, never an estimated one.
final cylinderBreathStartsProvider = FutureProvider.autoDispose
    .family<Map<String, List<int>>, String>((ref, diveId) async {
      final pressures = await ref.watch(tankPressuresProvider(diveId).future);
      return {
        for (final MapEntry(key: tankId, value: series) in pressures.entries)
          if (cylinderBreathStarts([
                for (final point in series)
                  (t: point.timestamp, bar: point.pressure),
              ])
              case final starts when starts.isNotEmpty)
            tankId: starts,
      };
    });
