import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_sealed_routes.dart';
import 'package:submersion/features/demo_mode/presentation/pages/demo_unavailable_page.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';

import '../../../helpers/global_test_defaults.dart';

/// Every full path the router declares, with `:params` kept.
Set<String> routerPaths(List<RouteBase> routes, [String parent = '']) {
  final out = <String>{};
  for (final r in routes) {
    if (r is GoRoute) {
      final full = r.path.startsWith('/')
          ? r.path
          : '${parent == '/' ? '' : parent}/${r.path}';
      out
        ..add(full)
        ..addAll(routerPaths(r.routes, full));
    } else if (r is ShellRouteBase) {
      out.addAll(routerPaths(r.routes, parent));
    }
  }
  return out;
}

void main() {
  tearDown(applyGlobalTestDefaults);

  test('every sealed prefix is a route the app declares', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final paths = routerPaths(
      container.read(appRouterProvider).configuration.routes,
    );

    expect(
      demoSealedRoutePrefixes.keys.where((prefix) => !paths.contains(prefix)),
      isEmpty,
    );
    expect(paths, contains('/dive-computers/:computerId/download'));
    expect(paths, contains(demoUnavailableLocation));
  });

  test('sealed locations map to their feature, at any depth', () {
    expect(demoSealedFeatureFor('/transfer'), DemoSealedFeature.fileImport);
    expect(
      demoSealedFeatureFor('/transfer/import-wizard?x=1'),
      DemoSealedFeature.fileImport,
    );
    expect(demoSealedFeatureFor('/settings/backup'), DemoSealedFeature.backup);
    // The page the Photos & videos row opens, which the old
    // /settings/media-storage route now redirects to.
    expect(
      demoSealedFeatureFor('/settings/photos-media/uploads'),
      DemoSealedFeature.mediaImport,
    );
    expect(
      demoSealedFeatureFor('/dive-computers/abc/download'),
      DemoSealedFeature.diveComputerDownload,
    );
  });

  test('an unsealed location such as /dives is never sealed', () {
    for (final location in [
      '/dives',
      '/dives/123',
      '/settings',
      '/settings/units',
      '/dive-computers',
      '/dive-computers/abc',
      '/transfers-not-a-route',
    ]) {
      expect(demoSealedFeatureFor(location), isNull, reason: location);
    }
  });

  test(
    'demoRedirect sends a sealed location to the unavailable page only while '
    'demo mode is active',
    () {
      expect(demoRedirect('/settings/backup'), isNull);

      DemoModeGate.instance.debugActive = true;

      expect(
        demoRedirect('/settings/backup'),
        '$demoUnavailableLocation?feature=backup',
      );
      expect(demoRedirect('/dives'), isNull);
      expect(demoRedirect(demoUnavailableLocation), isNull);
    },
  );

  test('a sealed settings page opens as the unavailable page in a pane', () {
    Widget page(Uri _) => const Text('real page');

    expect(SettingsPaneNavigator.pageAt('/settings/backup', page), isA<Text>());

    DemoModeGate.instance.debugActive = true;

    expect(
      SettingsPaneNavigator.pageAt('/settings/backup', page),
      isA<DemoUnavailablePage>().having(
        (p) => p.feature,
        'feature',
        DemoSealedFeature.backup,
      ),
    );
    expect(SettingsPaneNavigator.pageAt('/settings/units', page), isA<Text>());
  });
}
