import 'package:submersion/core/platform/device_capabilities_model.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';

/// The native capabilities, from the operating system, reproducing the
/// checks the screens made for themselves before this object existed.
DeviceCapabilities currentDeviceCapabilities() {
  final mobile = HostPlatform.isAndroid || HostPlatform.isIOS;
  final mobileOrDesktopWithRadios =
      mobile || HostPlatform.isMacOS || HostPlatform.isWindows;
  return DeviceCapabilities(
    diveComputerDownload: true,
    nfc: mobile,
    nearby: mobileOrDesktopWithRadios,
    healthImport: mobile,
    devicePhotoLibrary: mobile || HostPlatform.isMacOS,
    mediaAttach: true,
    biometricLock: mobileOrDesktopWithRadios,
    databaseEncryption: true,
    backgroundTasks: true,
    offlineMapTiles: true,
    backupRestore: true,
    sqliteImport: true,
    demoMode: true,
    agentAccess: hasDesktopWindow(),
    autoUpdate: UpdateChannelConfig.isAutoUpdateEnabled,
    ocrImport: mobileOrDesktopWithRadios,
    customDatabaseFolder: true,
    revealInFileManager: HostPlatform.isDesktop,
    cloudICloud: HostPlatform.isApple,
    cloudGit: true,
    cloudGoogleDrive: GoogleDriveClientConfig.isSupportedOnThisPlatform,
    isBrowser: false,
  );
}
