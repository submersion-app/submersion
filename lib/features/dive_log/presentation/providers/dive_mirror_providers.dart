import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final diveMirrorServiceProvider = Provider<DiveMirrorService>(
  (ref) => DiveMirrorService(
    dives: ref.watch(diveRepositoryProvider),
    buddies: ref.watch(buddyRepositoryProvider),
    divers: ref.watch(diverRepositoryProvider),
  ),
);

/// The other dives in this dive's outing (issue #2002). Empty for a dive
/// with no outing. Follows the dives tick so a sibling created, filled or
/// deleted elsewhere shows up.
final siblingDivesProvider = FutureProvider.autoDispose
    .family<List<Dive>, String>((ref, diveId) async {
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      final dive = await repository.getDiveById(diveId);
      final outingId = dive?.outingId;
      if (outingId == null) return const [];
      return [
        for (final d in await repository.getDivesByOutingId(outingId))
          if (d.id != diveId) d,
      ];
    });

/// Linked buddies on the dive whose profile has no sibling yet. Reads
/// dives, buddies and divers, so it follows all three ticks.
final mirrorCandidatesProvider = FutureProvider.autoDispose
    .family<List<MirrorCandidate>, String>((ref, diveId) {
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(buddyRepositoryProvider).watchBuddiesChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(diverRepositoryProvider).watchDiversChanges(),
      );
      return ref.watch(diveMirrorServiceProvider).candidates(diveId);
    });
