import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';

const ProfileSeriesCodec _codec = ProfileSeriesCodec();

/// Decodes one stored series row into a [ProfileSeries].
///
/// Throws a `ProfileSeriesCodecException` when the blob does not decode; each
/// caller decides what an unreadable row means for it. Pure and free of
/// database or logger state, so it runs on a background isolate as readily
/// as on the UI one (#3506).
ProfileSeries decodeProfileSeriesRow(DiveProfileSeriesRow row) {
  return ProfileSeries(
    id: row.id,
    diveId: row.diveId,
    computerId: row.computerId,
    sourceId: row.sourceId,
    isPrimary: row.isPrimary,
    summary: ProfileSeriesSummary(
      sampleCount: row.sampleCount,
      startTimestamp: row.startTimestamp,
      endTimestamp: row.endTimestamp,
      maxDepth: row.maxDepth,
      firstDepth: row.firstDepth,
      lastDepth: row.lastDepth,
      hasDecoType: row.hasDecoType,
      hasDecoStop: row.hasDecoStop,
      hasPositiveCeiling: row.hasPositiveCeiling,
    ),
    samples: _codec.decode(row.samples),
    codecVersion: row.codecVersion,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    hlc: row.hlc,
    activatedAt: row.activatedAt,
  );
}
