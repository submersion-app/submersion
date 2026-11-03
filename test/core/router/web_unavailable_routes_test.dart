import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/router/app_router.dart';
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

/// Route paths as the address bar shows them. GoRouter joins a nested
/// route's relative path onto its parent with a slash: these are URLs, not
/// file paths.
Set<String> _fullPaths(List<RouteBase> routes, String parent) {
  final paths = <String>{};
  for (final route in routes) {
    if (route is GoRoute) {
      final full = route.path.startsWith('/')
          ? route.path
          : '$parent/${route.path}';
      paths.add(full);
      paths.addAll(_fullPaths(route.routes, full));
    } else if (route is ShellRoute) {
      paths.addAll(_fullPaths(route.routes, parent));
    } else if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        paths.addAll(_fullPaths(branch.routes, parent));
      }
    }
  }
  return paths;
}

void main() {
  group('the table against the router', () {
    test('every sealed prefix is a route the router serves', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final paths = _fullPaths(
        container.read(appRouterProvider).configuration.routes,
        '',
      );
      for (final prefix in [
        ...webUnavailableRoutePrefixes.keys,
        ...webUnavailableSections.keys,
      ]) {
        expect(
          paths,
          contains(prefix),
          reason:
              '$prefix matches no route, so the page it was meant to seal '
              'is reachable in a browser',
        );
      }
    });

    test('the nearby pairing page is sealed', () {
      expect(
        webUnavailableFeatureFor('/settings/cloud-sync/nearby-pair'),
        WebUnavailableFeature.nearby,
      );
    });
  });

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
        webUnavailableFeatureFor('/settings/cloud-sync/nearby-pair'),
        WebUnavailableFeature.nearby,
      );
      expect(
        webUnavailableFeatureFor('/settings/offline-maps'),
        WebUnavailableFeature.offlineMaps,
      );
      expect(
        webUnavailableFeatureFor('/settings/agent-access'),
        WebUnavailableFeature.agentAccess,
      );
    });

    test('matches a section a page selects that the browser cannot '
        'serve', () {
      // Transfer's dive computers section starts a Bluetooth scan.
      expect(
        webUnavailableFeatureFor('/transfer?selected=computers'),
        WebUnavailableFeature.diveComputers,
      );
      expect(webUnavailableFeatureFor('/transfer?selected=import'), isNull);
      expect(webUnavailableFeatureFor('/transfer'), isNull);
    });

    test('leaves every other route alone', () {
      expect(webUnavailableFeatureFor('/dashboard'), isNull);
      expect(webUnavailableFeatureFor('/dives'), isNull);
      expect(webUnavailableFeatureFor('/settings/backup'), isNull);
      // Restore works in a browser (issue #4121).
      expect(webUnavailableFeatureFor('/settings/backup/restore'), isNull);
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
