import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/data_quality/data/services/hundredfold_gas_mix_repair.dart';

/// The repair the launch runs; tests override it.
final hundredfoldGasMixRepairProvider = Provider<HundredfoldGasMixRepair>(
  (ref) => HundredfoldGasMixRepair(),
);

/// Divides the cylinder mixes older imports stored 100 times too high, at
/// launch (issue #4714). Every launch, not once: it costs one query when
/// there is nothing to do, and puts right a value synced in since from a
/// device on an older version.
///
/// Contains its own failures: the call site is fire-and-forget, so an
/// escaping throw would land in the zone handler with nothing to catch it.
/// A failure leaves the mixes as they were for the next launch.
// no-tick: the value is a CLOSURE, not a query result. Every read happens
// inside it at call time via ref.read, so there is no cached row to go stale.
final launchGasMixRepairProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      await ref.read(hundredfoldGasMixRepairProvider).rescaleAll();
    } on Object catch (e, stackTrace) {
      LoggerService.forClass(HundredfoldGasMixRepair).warning(
        'Could not repair impossible gas mixes',
        error: e,
        stackTrace: stackTrace,
      );
    }
  };
});
