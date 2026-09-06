import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// One dive the diver can copy their weighting from: the dive itself (for the
/// date/site subtitle) and its weight entries.
typedef WeightingCopySource = ({Dive dive, List<DiveWeight> weights});

/// Recent dives of the current diver that carry a weighting, most-recent first,
/// for the "copy weighting from a dive" picker (issue #1609).
///
/// [divesProvider] is already recent-first and diver-scoped but drops weights
/// for list views, so this fills them back in for the top slice only.
final weightingCopySourcesProvider =
    FutureProvider.autoDispose<List<WeightingCopySource>>((ref) async {
      final repo = ref.watch(diveRepositoryProvider);
      final dives = await ref.watch(divesProvider.future);
      final recent = dives.take(60).toList();
      final byDive = await repo.getWeightsForDives(recent.map((d) => d.id));

      final sources = <WeightingCopySource>[];
      for (final dive in recent) {
        final weights = byDive[dive.id];
        if (weights != null && weights.isNotEmpty) {
          sources.add((dive: dive, weights: weights));
        }
        if (sources.length == 30) break;
      }
      return sources;
    });
