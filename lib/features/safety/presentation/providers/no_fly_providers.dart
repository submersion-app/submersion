import 'dart:async';

import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Active flying-after-diving restriction for the current diver, or null.
/// Its [NoFlyStatus.until] is a true UTC instant.
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

  // Dive end times are stored wall-clock-as-UTC. Read them in the device's
  // zone to get real instants before adding a guideline interval: compared
  // against the true UTC instant as stored, a dive that just surfaced east of
  // UTC looked like a future dive and was ignored (issue #2587), and interval
  // arithmetic on clock digits is an hour off across a DST change.
  final now = clock.now().toUtc();
  // The query compares stored digits, so its bound is padded by a day to
  // cover any UTC offset; evaluate() applies the exact lookback.
  final stored = await repository.getNoFlyDiveInputs(
    since: asWallClockUtc(
      now.toLocal(),
    ).subtract(NoFlyService.lookback + const Duration(days: 1)),
    diverId: diverId,
  );
  final dives = [
    for (final dive in stored)
      NoFlyDiveInput(
        endTime: fromWallClockUtc(dive.endTime).toUtc(),
        hadDecoObligation: dive.hadDecoObligation,
      ),
  ];
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
    final untilExpiry = status.until.difference(clock.now().toUtc());
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
