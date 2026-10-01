import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Active flying-after-diving restriction for the current diver, or null.
///
/// Self-invalidates on dive-table writes (import, sync, edit). The countdown
/// display refreshes in the UI layer; this provider anchors the deadline.
final noFlyStatusProvider = FutureProvider<NoFlyStatus?>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());

  final diverId = ref.watch(currentDiverIdProvider);
  final preset = ref.watch(settingsProvider.select((s) => s.noFlyPreset));

  // No active diver yet (transient at startup, or a fresh install): report no
  // restriction rather than folding every diver's dives into one countdown.
  // `getNoFlyDiveInputs` drops its diver filter when diverId is null, which
  // would otherwise scan the whole logbook.
  if (diverId == null) return null;

  // Dive end times are wall-clock-as-UTC, so "now" must be too. The true UTC
  // instant runs ahead of or behind them by the device's UTC offset: east of
  // UTC a dive that just surfaced looked like a future dive and was ignored
  // until the offset elapsed (issue #2587).
  final now = NoFlyService.wallClockNowUtc();
  final dives = await repository.getNoFlyDiveInputs(
    since: now.subtract(NoFlyService.lookback),
    diverId: diverId,
  );
  final status = const NoFlyService().evaluate(
    dives: dives,
    preset: preset,
    now: now,
  );

  // The status is a snapshot: nothing writes to the dive table when a
  // restriction naturally expires, so schedule a self-invalidation just past
  // the deadline. Without it the provider (and the dashboard alert that reads
  // it) would keep reporting an expired restriction until the next dive write.
  if (status != null) {
    final untilExpiry = status.until.difference(NoFlyService.wallClockNowUtc());
    if (untilExpiry > Duration.zero) {
      final timer = Timer(
        untilExpiry + const Duration(seconds: 1),
        ref.invalidateSelf,
      );
      ref.onDispose(timer.cancel);
    }
  }
  return status;
});
