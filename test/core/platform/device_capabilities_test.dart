import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/platform/device_capabilities_web.dart' as web;
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';

void main() {
  group('the browser table', () {
    const caps = DeviceCapabilities.web;

    test('offers nothing the hardware, files or OS provide', () {
      expect(caps.isBrowser, isTrue);
      expect(caps.cloudGoogleDrive, isTrue);
      // The picker reads a backup into memory (issue #4121).
      expect(caps.backupRestore, isTrue);
      for (final (name, value) in [
        ('diveComputerDownload', caps.diveComputerDownload),
        ('nfc', caps.nfc),
        ('nearby', caps.nearby),
        ('healthImport', caps.healthImport),
        ('devicePhotoLibrary', caps.devicePhotoLibrary),
        ('mediaAttach', caps.mediaAttach),
        ('biometricLock', caps.biometricLock),
        ('databaseEncryption', caps.databaseEncryption),
        ('backgroundTasks', caps.backgroundTasks),
        ('offlineMapTiles', caps.offlineMapTiles),
        ('sqliteImport', caps.sqliteImport),
        ('demoMode', caps.demoMode),
        ('agentAccess', caps.agentAccess),
        ('autoUpdate', caps.autoUpdate),
        ('ocrImport', caps.ocrImport),
        ('customDatabaseFolder', caps.customDatabaseFolder),
        ('revealInFileManager', caps.revealInFileManager),
        ('cloudICloud', caps.cloudICloud),
        ('cloudGit', caps.cloudGit),
      ]) {
        expect(value, isFalse, reason: name);
      }
    });

    test('is what the web file answers', () {
      expect(web.currentDeviceCapabilities(), same(DeviceCapabilities.web));
    });
  });

  group('the native value on this VM', () {
    final caps = currentDeviceCapabilities();

    test('reflects the host platform', () {
      final mobile = HostPlatform.isAndroid || HostPlatform.isIOS;
      expect(caps.isBrowser, isFalse);
      expect(caps.diveComputerDownload, isTrue);
      // Every native platform: nothing gated these before the table existed,
      // and Linux reads paper logs through Tesseract.
      expect(caps.nearby, isTrue);
      expect(caps.ocrImport, isTrue);
      expect(caps.nfc, mobile);
      expect(caps.healthImport, mobile);
      expect(caps.devicePhotoLibrary, mobile || HostPlatform.isMacOS);
      expect(caps.cloudICloud, HostPlatform.isApple);
      expect(caps.revealInFileManager, HostPlatform.isDesktop);
      expect(caps.cloudGit, isTrue);
      expect(caps.mediaAttach, isTrue);
      expect(caps.backupRestore, isTrue);
    });

    test('matches the gates it replaces', () {
      expect(caps.agentAccess, hasDesktopWindow());
      expect(caps.autoUpdate, UpdateChannelConfig.isAutoUpdateEnabled);
      expect(
        caps.cloudGoogleDrive,
        GoogleDriveClientConfig.isSupportedOnThisPlatform,
      );
    });

    test('the storage capabilities derive from it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final storage = container.read(storagePlatformCapabilitiesProvider);
      expect(storage.supportsICloud, caps.cloudICloud);
      expect(storage.supportsGoogleDrive, caps.cloudGoogleDrive);
      expect(storage.supportsCustomFolder, caps.customDatabaseFolder);
      final browser = ProviderContainer(
        overrides: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        ],
      );
      addTearDown(browser.dispose);
      final webStorage = browser.read(storagePlatformCapabilitiesProvider);
      expect(webStorage.supportsICloud, isFalse);
      expect(webStorage.supportsCustomFolder, isFalse);
      expect(webStorage.supportsGoogleDrive, isTrue);
    });
  });

  test('copyWith changes only the named capabilities', () {
    final phoneLike = DeviceCapabilities.web.copyWith(nfc: true);
    expect(phoneLike.nfc, isTrue);
    expect(phoneLike.isBrowser, isTrue);
    expect(phoneLike.nearby, isFalse);
    expect(phoneLike.cloudGoogleDrive, isTrue);
    expect(DeviceCapabilities.web.nfc, isFalse);
  });
}
