import 'package:drift/drift.dart';

import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// The per-tile markers the library grid draws (issue #4218), as extra
/// columns of the library page query.
///
/// Each is a correlated EXISTS rather than a join, so an item with three
/// people tags is still one row (a join would repeat it and break the keyset
/// cursor), and each probe is one lookup on an index the tables already
/// carry: `idx_media_people_media`, `idx_media_species_media` and
/// `idx_media_enrichment_media`. Computing them in the page query, rather than
/// asking per tile, keeps a scrolling grid at one query per page.
///
/// The SQL names `media` and `dives` by table name, so it is only valid in a
/// query that selects from `media` and left-joins `dives` unaliased, as
/// `MediaLibraryRepository.getPage` does.
abstract final class LibraryTileMarkers {
  /// Anyone tagged: a buddy, or any diver's Me tag.
  static const hasPeople = CustomExpression<bool>(
    'EXISTS (SELECT 1 FROM media_people mp WHERE mp.media_id = media.id)',
  );

  /// Any species tagged.
  static const hasSpecies = CustomExpression<bool>(
    'EXISTS (SELECT 1 FROM media_species ms WHERE ms.media_id = media.id)',
  );

  /// A time in the item's own dive that the profile chart would draw.
  ///
  /// Mirrors what `photoMarkersFromMedia` asks before drawing a marker: an
  /// elapsed time and a depth, a real profile match, and (per
  /// `MediaEnrichment.isWithinDiveWindow`) either a pin or a capture inside
  /// [MediaDiveWindow] around the dive. The chart measures the dive by its
  /// last profile sample, which SQL cannot reach since samples are stored
  /// packed, so the upper bound uses the dive's runtime instead; the hour of
  /// slack after the dive dwarfs the difference between the two. A dive with no runtime
  /// checks only the lower bound rather than marking nothing.
  ///
  /// Keyed on `media.dive_id` so a row left behind for a previous dive by a
  /// re-link does not count.
  static final hasTimeInDive = CustomExpression<bool>(
    'EXISTS (SELECT 1 FROM media_enrichment me '
    'WHERE me.media_id = media.id '
    'AND me.dive_id = media.dive_id '
    'AND me.elapsed_seconds IS NOT NULL '
    'AND me.depth_meters IS NOT NULL '
    "AND me.match_confidence <> '${MatchConfidence.noProfile.name}' "
    "AND (me.match_confidence = '${MatchConfidence.manual.name}' "
    'OR (me.elapsed_seconds >= ${-MediaDiveWindow.before.inSeconds} '
    'AND (dives.runtime IS NULL '
    'OR me.elapsed_seconds <= dives.runtime + '
    '${MediaDiveWindow.after.inSeconds}))))',
  );

  /// All three, in the order the page query adds them.
  static final all = <Expression<bool>>[hasPeople, hasSpecies, hasTimeInDive];
}
