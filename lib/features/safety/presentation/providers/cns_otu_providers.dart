import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/entities/cns_otu_snapshot.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';

/// Static inputs for the current diver's CNS/OTU readout, or null when
/// there is no executed dive on record.
///
/// Self-invalidates on dive-table writes (import, sync, edit), same pattern
/// as [noFlyStatusProvider]. Unlike that provider, there is no self-scheduled
/// expiry timer here: the live CNS% is re-derived from this snapshot on
/// every UI tick by [CnsOtuLiveService] rather than cached, so pure elapsed
/// time never makes this provider's cached value stale.
final cnsOtuSnapshotProvider = FutureProvider<CnsOtuSnapshot?>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());

  final diverId = ref.watch(currentDiverIdProvider);
  // No active diver yet (transient at startup, or a fresh install): report no
  // snapshot rather than folding every diver's dives into one readout.
  if (diverId == null) return null;

  // Dive end times are stored wall-clock-as-UTC, so the "at or before now"
  // bound must be evaluated in the same frame (see wallClockNowUtc's doc and
  // issue #2587 for why DateTime.now().toUtc() is wrong here).
  final lastDive = await repository.getMostRecentDiveTimes(
    diverId: diverId,
    notAfter: NoFlyService.wallClockNowUtc(),
  );
  if (lastDive == null) return null;

  // Independent lookups (full profile analysis vs. a plain DB range query),
  // run concurrently rather than one after the other.
  final (analysis, weeklyOtu) = await (
    ref.watch(profileAnalysisProvider(lastDive.id).future),
    ref.watch(weeklyOtuProvider(lastDive.id).future),
  ).wait;
  if (analysis == null) return null;

  return CnsOtuSnapshot(
    lastDiveId: lastDive.id,
    lastDiveEnd: lastDive.effectiveExitTime,
    exposure: analysis.o2Exposure,
    weeklyOtu: weeklyOtu,
  );
});
