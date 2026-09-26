import 'package:photo_manager/photo_manager.dart';

/// The two ways back to a photo outside the user's limited selection
/// (media sync program spec 6.3). Both hand off to the system, and both
/// return once the user comes back; the caller re-resolves then.
abstract interface class PhotoAccessActions {
  /// Opens this app's page in the system settings, where full photo access
  /// is granted.
  Future<void> openSettings();

  /// Opens the system's limited-selection sheet, where the user adds photos
  /// to what the app may see (iOS 14 and later, Android 14 and later).
  Future<void> chooseMorePhotos();
}

/// [PhotoAccessActions] through photo_manager.
class PhotoManagerAccessActions implements PhotoAccessActions {
  const PhotoManagerAccessActions();

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<void> chooseMorePhotos() => PhotoManager.presentLimited();
}
