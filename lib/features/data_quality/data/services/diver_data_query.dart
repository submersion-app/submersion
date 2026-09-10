import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/services/diver_data_sql.dart';
import 'package:submersion/features/data_quality/domain/entities/diver_data_summary.dart';

/// Reads what one dive carries of the diver's own work.
///
/// Separate from `QualityContextBuilder`, which asks the same question as a
/// boolean for every dive of a scan. This runs once, for one dive, when a
/// destructive confirmation has to say what it is about to take (#1729), so
/// it can afford the counts the scan cannot.
class DiverDataQuery {
  AppDatabase get _db => DatabaseService.instance.database;

  /// The summary for [diveId], or null when no such dive exists. A caller
  /// showing a confirmation treats null as "nothing to say" rather than as
  /// "carries nothing": the row being gone is not evidence it was empty.
  Future<DiverDataSummary?> forDive(String diveId) async {
    final rows = await _db
        .customSelect(
          'SELECT $kDiverDataCountsSql FROM dives WHERE id = ?1',
          variables: [Variable.withString(diveId)],
          readsFrom: diverDataTables(_db),
        )
        .get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    int count(String column) => row.read<int?>(column) ?? 0;
    bool flag(String column) => count(column) != 0;
    return DiverDataSummary(
      gear: count('gear_count'),
      weights: count('weight_count'),
      buddies: count('buddy_count'),
      tags: count('tag_count'),
      sightings: count('sighting_count'),
      photosAndVideos: count('photo_video_count'),
      attachments: count('attachment_count'),
      customFields: count('custom_field_count'),
      hasNotes: flag('has_notes'),
      hasRating: flag('has_rating'),
      isFavorite: flag('has_favorite'),
      hasSite: flag('has_site'),
      hasTrip: flag('has_trip'),
      hasDiveCenter: flag('has_dive_center'),
      hasCourse: flag('has_course'),
    );
  }
}
