import 'package:shared_preferences/shared_preferences.dart';

/// Device-local transfer policies (design spec section 9). Stored in
/// SharedPreferences like the attach state: these are per-device choices about
/// when this device may spend bandwidth, and must not ride a database restore.
///
/// Upload *quality* deliberately does not live here. It decides what bytes the
/// library permanently contains, not what this device may spend, so it is a
/// synced setting -- see `MediaUploadQualityPolicy`.
class MediaStorePolicies {
  MediaStorePolicies({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const String autoUploadKey = 'media_store_auto_upload';
  static const String photosOnCellularKey = 'media_store_photos_on_cellular';
  static const String videosOnCellularKey = 'media_store_videos_on_cellular';

  Future<SharedPreferences> get _resolved async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<bool> autoUpload() async =>
      (await _resolved).getBool(autoUploadKey) ?? true;

  Future<void> setAutoUpload(bool value) async =>
      (await _resolved).setBool(autoUploadKey, value);

  Future<bool> photosOnCellular() async =>
      (await _resolved).getBool(photosOnCellularKey) ?? true;

  Future<void> setPhotosOnCellular(bool value) async =>
      (await _resolved).setBool(photosOnCellularKey, value);

  /// Default false. Phase 2 does not upload videos at all; this ships now
  /// so Phase 3's multipart transfer only has to consume it.
  Future<bool> videosOnCellular() async =>
      (await _resolved).getBool(videosOnCellularKey) ?? false;

  Future<void> setVideosOnCellular(bool value) async =>
      (await _resolved).setBool(videosOnCellularKey, value);
}
