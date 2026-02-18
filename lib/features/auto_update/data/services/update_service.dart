import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

abstract class UpdateService {
  /// Background update check. May return [UpToDate] even when an update exists
  /// if the platform handles its own update UI (e.g. Sparkle on macOS).
  Future<UpdateStatus> checkForUpdate();

  /// User-initiated (foreground) update check. Shows platform-native UI when
  /// available. Default implementation delegates to [checkForUpdate].
  Future<UpdateStatus> checkForUpdateInteractively() => checkForUpdate();
}
