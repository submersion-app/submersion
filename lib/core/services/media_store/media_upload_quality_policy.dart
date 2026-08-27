import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

/// Library-wide media upload quality, stored in the synced `settings`
/// key-value table.
///
/// Deliberately separate from `MediaStorePolicies`: those flags answer "may
/// this device spend bandwidth right now", which is a per-device question.
/// Quality answers "what bytes should the library permanently contain", which
/// is not. A non-Original level uploads a compressed rendition *instead of*
/// the original, and the original then never leaves the device -- so the
/// choice decides the library's archival fidelity, and every device must agree
/// on it. Storing it per-device let whichever device happened to hold a file
/// decide that file's fidelity.
class MediaUploadQualityPolicy {
  MediaUploadQualityPolicy({AppSettingsRepository? settings})
    : _settings = settings ?? AppSettingsRepository();

  final AppSettingsRepository _settings;

  static const String photoQualityKey = 'media_upload_quality_photo';
  static const String videoQualityKey = 'media_upload_quality_video';

  Future<MediaUploadQuality> photoUploadQuality() => _read(photoQualityKey);

  Future<void> setPhotoUploadQuality(MediaUploadQuality value) =>
      _settings.setRawSetting(photoQualityKey, value.name);

  Future<MediaUploadQuality> videoUploadQuality() => _read(videoQualityKey);

  Future<void> setVideoUploadQuality(MediaUploadQuality value) =>
      _settings.setRawSetting(videoQualityKey, value.name);

  /// The level for [type]'s media (photos vs video).
  Future<MediaUploadQuality> qualityFor(MediaType type) =>
      type == MediaType.video ? videoUploadQuality() : photoUploadQuality();

  /// Reads never throw. [AppSettingsRepository.getRawSetting] already degrades
  /// to null on a DB error, but the collaborator is injected and this class
  /// does not control every implementation, so the guard stays at the seam.
  /// An unrecognized value (a level written by a future build) is treated the
  /// same way, mirroring the pipeline's tolerant override parse.
  Future<MediaUploadQuality> _read(String key) async {
    final String? raw;
    try {
      raw = await _settings.getRawSetting(key);
    } catch (_) {
      return MediaUploadQuality.original;
    }
    if (raw == null) return MediaUploadQuality.original;
    try {
      return MediaUploadQuality.values.byName(raw);
    } on ArgumentError {
      return MediaUploadQuality.original;
    }
  }
}
