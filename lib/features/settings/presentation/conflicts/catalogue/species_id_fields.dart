import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict labels for marine life results (issue #4876). They merge as
/// clock-guarded rows and raise no conflict cards; the coverage guard in
/// test/features/settings/presentation/conflicts/ keeps every synced column
/// labelled all the same. Keyed by entity, since names such as `runId` and
/// `decision` mean something particular here.
final Map<String, ConflictField> speciesIdOverrides = {
  'mediaIdentificationRuns.packVersion': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_packVersion,
    FieldKind.shortText,
  ),
  'mediaIdentificationRuns.detectorId': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_detectorId,
    FieldKind.opaque,
  ),
  'mediaIdentificationRuns.classifierId': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_classifierId,
    FieldKind.opaque,
  ),
  'mediaIdentificationRuns.locationCell': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_locationCell,
    FieldKind.number,
  ),
  'mediaIdentificationRuns.analysedAt': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_analysedAt,
    FieldKind.dateTime,
  ),
  'mediaIdentificationRuns.imageWidth': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_imageWidth,
    FieldKind.number,
  ),
  'mediaIdentificationRuns.imageHeight': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_imageHeight,
    FieldKind.number,
  ),
  'mediaIdentificationRuns.detectionCount': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_detectionCount,
    FieldKind.number,
  ),
  'mediaIdentificationRuns.scannedMs': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_scannedMs,
    FieldKind.number,
  ),
  'mediaIdentificationRuns.videoDurationMs': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_videoDurationMs,
    FieldKind.number,
  ),
  'mediaIdentificationRuns.scannedRanges': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_scannedRanges,
    FieldKind.opaque,
  ),
  'mediaIdentificationRuns.analysedBy': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_analysedBy,
    FieldKind.opaque,
  ),
  'mediaIdentificationRuns.runId': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_runId,
    FieldKind.opaque,
  ),
  'mediaIdentificationRuns.namingBars': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationRuns_namingBars,
    FieldKind.opaque,
  ),
  'mediaIdentifications.boxX': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_boxX,
    FieldKind.fraction,
  ),
  'mediaIdentifications.boxY': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_boxY,
    FieldKind.fraction,
  ),
  'mediaIdentifications.boxWidth': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_boxWidth,
    FieldKind.fraction,
  ),
  'mediaIdentifications.boxHeight': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_boxHeight,
    FieldKind.fraction,
  ),
  'mediaIdentifications.boxPixelWidth': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_boxPixelWidth,
    FieldKind.number,
  ),
  'mediaIdentifications.boxPixelHeight': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_boxPixelHeight,
    FieldKind.number,
  ),
  'mediaIdentifications.detectorScore': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_detectorScore,
    FieldKind.fraction,
  ),
  'mediaIdentifications.openScore': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_openScore,
    FieldKind.fraction,
  ),
  'mediaIdentifications.candidatesJson': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_candidatesJson,
    FieldKind.opaque,
  ),
  'mediaIdentifications.locationLimited': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_locationLimited,
    FieldKind.boolean,
  ),
  'mediaIdentifications.suggestable': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_suggestable,
    FieldKind.boolean,
  ),
  'mediaIdentifications.decision': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_decision,
    FieldKind.shortText,
  ),
  'mediaIdentifications.decidedSpeciesId': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_decidedSpeciesId,
    FieldKind.reference,
  ),
  'mediaIdentifications.decidedAt': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_decidedAt,
    FieldKind.dateTime,
  ),
  'mediaIdentifications.claimedSpeciesId': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_claimedSpeciesId,
    FieldKind.reference,
  ),
  'mediaIdentifications.startMs': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_startMs,
    FieldKind.number,
  ),
  'mediaIdentifications.endMs': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_endMs,
    FieldKind.number,
  ),
  'mediaIdentifications.bestMs': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_bestMs,
    FieldKind.number,
  ),
  'mediaIdentifications.trackPath': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_trackPath,
    FieldKind.opaque,
  ),
  'mediaIdentifications.confident': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_confident,
    FieldKind.boolean,
  ),
  'mediaIdentifications.specific': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_specific,
    FieldKind.boolean,
  ),
  'mediaIdentifications.runId': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_runId,
    FieldKind.opaque,
  ),
  'mediaIdentifications.decisionHlc': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentifications_decisionHlc,
    FieldKind.opaque,
  ),
  'mediaIdentificationCrops.jpeg': ConflictField(
    (l) => l.settings_conflict_field_mediaIdentificationCrops_jpeg,
    FieldKind.opaque,
  ),
};
