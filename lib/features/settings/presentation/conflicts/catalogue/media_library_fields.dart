import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict labels and value kinds for media, presets, saved queries and app settings (#694). Generated from a
/// reviewed column list; the coverage guard in
/// test/features/settings/presentation/conflicts/ keeps it complete.
final Map<String, ConflictField> mediaLibraryFields = {
  'accountIdentifier': ConflictField(
    (l) => l.settings_conflict_field_accountIdentifier,
    FieldKind.shortText,
  ),
  'bboxHeight': ConflictField(
    (l) => l.settings_conflict_field_bboxHeight,
    FieldKind.fraction,
  ),
  'bboxWidth': ConflictField(
    (l) => l.settings_conflict_field_bboxWidth,
    FieldKind.fraction,
  ),
  'bboxX': ConflictField(
    (l) => l.settings_conflict_field_bboxX,
    FieldKind.fraction,
  ),
  'bboxY': ConflictField(
    (l) => l.settings_conflict_field_bboxY,
    FieldKind.fraction,
  ),
  'bookmarkRef': ConflictField(
    (l) => l.settings_conflict_field_bookmarkRef,
    FieldKind.opaque,
  ),
  'caption': ConflictField(
    (l) => l.settings_conflict_field_caption,
    FieldKind.longText,
  ),
  'cloudAssetId': ConflictField(
    (l) => l.settings_conflict_field_cloudAssetId,
    FieldKind.opaque,
  ),
  'compressedLevel': ConflictField(
    (l) => l.settings_conflict_field_compressedLevel,
    FieldKind.shortText,
  ),
  'compressedSizeBytes': ConflictField(
    (l) => l.settings_conflict_field_compressedSizeBytes,
    FieldKind.number,
  ),
  'configJson': ConflictField(
    (l) => l.settings_conflict_field_configJson,
    FieldKind.opaque,
  ),
  'contentHash': ConflictField(
    (l) => l.settings_conflict_field_contentHash,
    FieldKind.opaque,
  ),
  'contentSizeBytes': ConflictField(
    (l) => l.settings_conflict_field_contentSizeBytes,
    FieldKind.number,
  ),
  'credentialsHostId': ConflictField(
    (l) => l.settings_conflict_field_credentialsHostId,
    FieldKind.opaque,
  ),
  'displayHint': ConflictField(
    (l) => l.settings_conflict_field_displayHint,
    FieldKind.shortText,
  ),
  'elapsedSeconds': ConflictField(
    (l) => l.settings_conflict_field_elapsedSeconds,
    FieldKind.durationSeconds,
  ),
  'entryKey': ConflictField(
    (l) => l.settings_conflict_field_entryKey,
    FieldKind.opaque,
  ),
  'filePath': ConflictField(
    (l) => l.settings_conflict_field_filePath,
    FieldKind.shortText,
  ),
  'fileType': ConflictField(
    (l) => l.settings_conflict_field_fileType,
    FieldKind.shortText,
  ),
  'filterJson': ConflictField(
    (l) => l.settings_conflict_field_filterJson,
    FieldKind.opaque,
  ),
  'format': ConflictField(
    (l) => l.settings_conflict_field_format,
    FieldKind.enumValue,
    enumLabel: manifestFormatLabeler,
  ),
  'height': ConflictField(
    (l) => l.settings_conflict_field_height,
    FieldKind.number,
  ),
  'imageData': ConflictField(
    (l) => l.settings_conflict_field_imageData,
    FieldKind.opaque,
  ),
  'isOrphaned': ConflictField(
    (l) => l.settings_conflict_field_isOrphaned,
    FieldKind.boolean,
  ),
  'lastSweepAt': ConflictField(
    (l) => l.settings_conflict_field_lastSweepAt,
    FieldKind.dateTime,
  ),
  'lastVerifiedAt': ConflictField(
    (l) => l.settings_conflict_field_lastVerifiedAt,
    FieldKind.dateTime,
  ),
  'localPath': ConflictField(
    (l) => l.settings_conflict_field_localPath,
    FieldKind.shortText,
  ),
  'manifestUrl': ConflictField(
    (l) => l.settings_conflict_field_manifestUrl,
    FieldKind.shortText,
  ),
  'manualElapsedSeconds': ConflictField(
    (l) => l.settings_conflict_field_manualElapsedSeconds,
    FieldKind.durationSeconds,
  ),
  'matchConfidence': ConflictField(
    (l) => l.settings_conflict_field_matchConfidence,
    FieldKind.enumValue,
    enumLabel: matchConfidenceLabeler,
  ),
  'originalFilename': ConflictField(
    (l) => l.settings_conflict_field_originalFilename,
    FieldKind.shortText,
  ),
  'platformAssetId': ConflictField(
    (l) => l.settings_conflict_field_platformAssetId,
    FieldKind.opaque,
  ),
  'pollIntervalSeconds': ConflictField(
    (l) => l.settings_conflict_field_pollIntervalSeconds,
    FieldKind.durationSeconds,
  ),
  'presetJson': ConflictField(
    (l) => l.settings_conflict_field_presetJson,
    FieldKind.opaque,
  ),
  'providerType': ConflictField(
    (l) => l.settings_conflict_field_providerType,
    FieldKind.shortText,
  ),
  'queryJson': ConflictField(
    (l) => l.settings_conflict_field_queryJson,
    FieldKind.opaque,
  ),
  'remoteAssetId': ConflictField(
    (l) => l.settings_conflict_field_remoteAssetId,
    FieldKind.opaque,
  ),
  'remoteCompressedUploadedAt': ConflictField(
    (l) => l.settings_conflict_field_remoteCompressedUploadedAt,
    FieldKind.dateTime,
  ),
  'remoteThumbUploadedAt': ConflictField(
    (l) => l.settings_conflict_field_remoteThumbUploadedAt,
    FieldKind.dateTime,
  ),
  'remoteUploadedAt': ConflictField(
    (l) => l.settings_conflict_field_remoteUploadedAt,
    FieldKind.dateTime,
  ),
  'retainInLibrary': ConflictField(
    (l) => l.settings_conflict_field_retainInLibrary,
    FieldKind.boolean,
  ),
  'signatureType': ConflictField(
    (l) => l.settings_conflict_field_signatureType,
    FieldKind.shortText,
  ),
  'signerName': ConflictField(
    (l) => l.settings_conflict_field_signerName,
    FieldKind.shortText,
  ),
  'sourceType': ConflictField(
    (l) => l.settings_conflict_field_sourceType,
    FieldKind.enumValue,
    enumLabel: mediaSourceTypeLabeler,
  ),
  'spec': ConflictField(
    (l) => l.settings_conflict_field_spec,
    FieldKind.opaque,
  ),
  'subject': ConflictField(
    (l) => l.settings_conflict_field_subject,
    FieldKind.shortText,
  ),
  'takenAt': ConflictField(
    (l) => l.settings_conflict_field_takenAt,
    FieldKind.wallClock,
  ),
  'temperatureCelsius': ConflictField(
    (l) => l.settings_conflict_field_temperatureCelsius,
    FieldKind.temperature,
  ),
  'thumbnailGeneratedAt': ConflictField(
    (l) => l.settings_conflict_field_thumbnailGeneratedAt,
    FieldKind.dateTime,
  ),
  'timestampOffsetSeconds': ConflictField(
    (l) => l.settings_conflict_field_timestampOffsetSeconds,
    FieldKind.durationSeconds,
  ),
  'uploadFactsHlc': ConflictField(
    (l) => l.settings_conflict_field_uploadFactsHlc,
    FieldKind.opaque,
  ),
  'url': ConflictField(
    (l) => l.settings_conflict_field_url,
    FieldKind.shortText,
  ),
  'verifyFactsHlc': ConflictField(
    (l) => l.settings_conflict_field_verifyFactsHlc,
    FieldKind.opaque,
  ),
  'viewMode': ConflictField(
    (l) => l.settings_conflict_field_viewMode,
    FieldKind.enumValue,
    enumLabel: listViewModeLabeler,
  ),
  'width': ConflictField(
    (l) => l.settings_conflict_field_width,
    FieldKind.number,
  ),
};

/// Columns whose meaning depends on the entity, keyed `entity.column`.
final Map<String, ConflictField> mediaLibraryOverrides = {
  'connectedAccounts.kind': ConflictField(
    (l) => l.settings_conflict_field_connectedAccounts_kind,
    FieldKind.shortText,
  ),
  'settings.key': ConflictField(
    (l) => l.settings_conflict_field_settings_key,
    FieldKind.shortText,
  ),
  'settings.value': ConflictField(
    (l) => l.settings_conflict_field_settings_value,
    FieldKind.shortText,
  ),
};
