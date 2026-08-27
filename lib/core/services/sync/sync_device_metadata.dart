import 'package:package_info_plus/package_info_plus.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/device_display_name_service.dart';

/// The identity resolved by [SyncDeviceMetadata.resolve].
typedef DeviceIdentity = ({String id, String? name, String? appVersion});

/// Resolves an identity without touching the platform. Lets callers that own
/// the identity (and tests) supply one directly.
typedef DeviceIdentityResolver = Future<DeviceIdentity> Function();

/// Who this device is, for anything that stamps an identity into the cloud:
/// library epoch markers, library moved markers, and per-device sync
/// manifests. One resolver so the three cannot drift apart.
class SyncDeviceMetadata {
  const SyncDeviceMetadata(
    this._syncRepository, {
    DeviceDisplayNameService displayName = const DeviceDisplayNameService(),
  }) : _displayName = displayName;

  final SyncRepository _syncRepository;
  final DeviceDisplayNameService _displayName;

  /// Each piece degrades independently to a safe default: markers are shown
  /// in banners and dialogs, so the origin must always be displayable.
  Future<DeviceIdentity> resolve() async {
    String id;
    try {
      id = await _syncRepository.getDeviceId();
    } catch (_) {
      // Non-empty sentinel: the marker's origin is rendered, so it must never
      // be blank.
      id = 'unknown';
    }
    // Null when nothing on this platform identifies the device; readers fall
    // back to a short device id.
    final name = await _displayName.resolve();
    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      appVersion = null;
    }
    return (id: id, name: name, appVersion: appVersion);
  }
}
