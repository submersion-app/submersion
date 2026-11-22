import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/local_day_changes.dart';
import 'package:submersion/features/dashboard/domain/home_outings.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/media/data/repositories/outing_cover_repository.dart';
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

/// How many of the newest dives Home reads to find its outings.
const _readLimit = 300;

final _log = LoggerService.forClass(HomeOuting);

/// The diver's recent outings for the Home Recent outings panel
/// (issue #4898), newest first, each with its chosen cover.
///
/// Reads the repositories directly with the current diver and no filter, as
/// every Home provider does, and rebuilds when a dive, trip, site, sighting
/// or media item changes and when the local day turns.
final homeRecentOutingsProvider = FutureProvider<List<HomeOuting>>((ref) async {
  final insights = ref.watch(insightsRepositoryProvider);
  final media = ref.watch(mediaRepositoryProvider);
  final coverRepository = ref.watch(outingCoverRepositoryProvider);
  ref.invalidateSelfWhen(insights.watchOutingChanges());
  ref.invalidateSelfWhen(media.watchMediaChanges());
  ref.invalidateSelfWhen(localDayChanges());
  final diverId = ref.watch(currentDiverIdProvider);

  // One row past the limit says whether older dives exist at all: exactly
  // [_readLimit] dives is the whole log, not a cut one.
  final read = await insights.getOutingDives(
    diverId: diverId,
    limit: _readLimit + 1,
  );
  final cut = read.length > _readLimit;
  final window = read.take(_readLimit).toList();
  // A trip the read cut through is read whole, so its card counts every
  // dive; only a trip-less outing at the cut can still be incomplete.
  final dives = cut
      ? {
          for (final d in [
            ...window,
            ...await insights.getOutingDivesForTrips(
              {for (final d in window) ?d.tripId}.toList(),
              diverId: diverId,
            ),
          ])
            d.id: d,
        }.values.toList()
      : window;
  final outings = groupOutings(dives, cutAt: cut ? window.last.dateTime : null);
  final covers = await _coversFor(coverRepository, outings);
  return [
    for (var i = 0; i < outings.length; i++)
      HomeOuting(outing: outings[i], cover: covers[i]),
  ];
});

/// Each outing's cover, in order, or null. A failed cover read leaves every
/// outing without one rather than taking the panel down: each still has its
/// skyline.
Future<List<MediaItem?>> _coversFor(
  OutingCoverRepository covers,
  List<Outing> outings,
) async {
  try {
    final outingOf = {
      for (var i = 0; i < outings.length; i++)
        for (final id in outings[i].diveIds) id: i,
    };
    final byOuting = [for (final _ in outings) <CoverCandidate>[]];
    for (final c in await covers.getCoverCandidates(outingOf.keys.toList())) {
      final i = outingOf[c.diveId];
      if (i != null) byOuting[i].add(c);
    }
    final chosen = [for (final c in byOuting) chooseOutingCover(c)];
    final items = {
      for (final item in await covers.getMediaByIds(chosen.nonNulls.toList()))
        item.id: item,
    };
    return [for (final id in chosen) items[id]];
  } catch (e, stackTrace) {
    _log.error(
      'Failed to read outing covers',
      error: e,
      stackTrace: stackTrace,
    );
    return List.filled(outings.length, null);
  }
}
