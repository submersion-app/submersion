import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/router/web_unavailable_routes.dart';

const _native = DeviceCapabilities(
  diveComputerDownload: true,
  nfc: true,
  nearby: true,
  healthImport: true,
  devicePhotoLibrary: true,
  mediaAttach: true,
  biometricLock: true,
  databaseEncryption: true,
  backgroundTasks: true,
  offlineMapTiles: true,
  backupRestore: true,
  sqliteImport: true,
  demoMode: true,
  agentAccess: true,
  autoUpdate: true,
  ocrImport: true,
  customDatabaseFolder: true,
  revealInFileManager: true,
  cloudICloud: true,
  cloudGit: true,
  cloudGoogleDrive: true,
  isBrowser: false,
);

void main() {
  group('webUnavailableFeatureFor', () {
    test('matches the routes the browser cannot serve, prefix and params', () {
      expect(
        webUnavailableFeatureFor('/dive-computers'),
        WebUnavailableFeature.diveComputers,
      );
      expect(
        webUnavailableFeatureFor('/dive-computers/abc/download?x=1'),
        WebUnavailableFeature.diveComputers,
      );
      expect(
        webUnavailableFeatureFor('/dives/scan'),
        WebUnavailableFeature.paperScan,
      );
      expect(
        webUnavailableFeatureFor('/settings/wearable-import'),
        WebUnavailableFeature.wearableImport,
      );
      expect(
        webUnavailableFeatureFor('/settings/nearby'),
        WebUnavailableFeature.nearby,
      );
      expect(
        webUnavailableFeatureFor('/settings/offline-maps'),
        WebUnavailableFeature.offlineMaps,
      );
      expect(
        webUnavailableFeatureFor('/settings/backup/restore'),
        WebUnavailableFeature.backupRestore,
      );
      expect(
        webUnavailableFeatureFor('/settings/agent-access'),
        WebUnavailableFeature.agentAccess,
      );
    });

    test('leaves every other route alone', () {
      expect(webUnavailableFeatureFor('/dashboard'), isNull);
      expect(webUnavailableFeatureFor('/dives'), isNull);
      expect(webUnavailableFeatureFor('/settings/backup'), isNull);
      expect(webUnavailableFeatureFor('/settings'), isNull);
    });
  });

  group('webUnavailableRedirect', () {
    test('sends a browser to the unavailable page for a sealed route', () {
      expect(
        webUnavailableRedirect(DeviceCapabilities.web, '/dive-computers'),
        '/unavailable-in-browser?feature=diveComputers',
      );
    });

    test('does nothing for other routes or on a native build', () {
      expect(webUnavailableRedirect(DeviceCapabilities.web, '/dives'), isNull);
      expect(webUnavailableRedirect(_native, '/dive-computers'), isNull);
      expect(
        webUnavailableRedirect(
          DeviceCapabilities.web,
          '/unavailable-in-browser?feature=nearby',
        ),
        isNull,
      );
    });
  });

  test('every feature carries a reason', () {
    for (final feature in WebUnavailableFeature.values) {
      expect(feature.reason, isA<WebUnavailableReason>(), reason: feature.name);
    }
  });

  test('the buddy swap screen is a nearby feature', () {
    expect(
      webUnavailableFeatureFor('/buddies/swap'),
      WebUnavailableFeature.nearby,
    );
    expect(webUnavailableFeatureFor('/buddies'), isNull);
  });
}
