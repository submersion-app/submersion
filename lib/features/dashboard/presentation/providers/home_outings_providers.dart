import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/local_day_changes.dart';
import 'package:submersion/features/dashboard/domain/home_outings.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/outing_cover_providers.dart';

/// An outing on Home with its cover, or none when it has no photo or video.
@immutable
class HomeOuting {
  final Outing outing;
  final MediaItem? cover;

  const HomeOuting({required this.outing, this.cover});
}

/// The diver's recent outings for the Home Recent outings panel
/// (issue #4898), newest first, each with its chosen cover.
///
/// Reads the repositories directly with the current diver and no filter, as
/// every Home provider does, and rebuilds on dive and media changes and when
/// the local day turns.
final homeRecentOutingsProvider = FutureProvider<List<HomeOuting>>((ref) async {
  final insights = ref.watch(insightsRepositoryProvider);
  final media = ref.watch(mediaRepositoryProvider);
  final covers = ref.watch(outingCoverRepositoryProvider);
  ref.invalidateSelfWhen(insights.watchInsightsChanges());
  ref.invalidateSelfWhen(media.watchMediaChanges());
  ref.invalidateSelfWhen(localDayChanges());
  final diverId = ref.watch(currentDiverIdProvider);

  final outings = groupOutings(await insights.getOutingDives(diverId: diverId));
  final candidates = await covers.getCoverCandidates([
    for (final o in outings) ...o.diveIds,
  ]);
  final chosen = [
    for (final o in outings)
      chooseOutingCover(candidates.where((c) => o.diveIds.contains(c.diveId))),
  ];
  final items = {
    for (final item in await covers.getMediaByIds(chosen.nonNulls.toList()))
      item.id: item,
  };
  return [
    for (var i = 0; i < outings.length; i++)
      HomeOuting(outing: outings[i], cover: items[chosen[i]]),
  ];
});
