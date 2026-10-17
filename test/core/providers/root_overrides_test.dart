import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/media_cache_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/viewer_fullscreen_mode_provider.dart';
import 'package:submersion/shared/services/incoming_share.dart';
import 'package:submersion/shared/services/navigation_ready_gate.dart';

class _NoProxy implements SystemProxyResolver {
  @override
  Future<SystemProxyResult> resolve(Uri probe) async => const SystemProxyNone();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hands the app its one ProxyController when given', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ProxyController(resolver: _NoProxy());
    addTearDown(controller.dispose);
    final container = ProviderContainer(
      overrides: rootProviderOverrides(
        prefs: prefs,
        logFileService: LogFileService(
          logDirectory: p.join(Directory.systemTemp.path, 'submersion-test'),
        ),
        proxyController: controller,
      ).cast(),
    );
    addTearDown(container.dispose);

    expect(container.read(proxyControllerProvider), same(controller));
  });

  test('supplies both providers that would otherwise throw', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Never initialized, so no directory is created; the override only has to
    // hand back the same instance.
    final logFileService = LogFileService(logDirectory: '/tmp/submersion-test');

    final container = ProviderContainer(
      overrides: rootProviderOverrides(
        prefs: prefs,
        logFileService: logFileService,
      ).cast(),
    );
    addTearDown(container.dispose);

    expect(container.read(sharedPreferencesProvider), same(prefs));
    expect(container.read(logFileServiceProvider), same(logFileService));
  });

  test('backs the clock sync settings with SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'dive_computer_clock_sync_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final logFileService = LogFileService(logDirectory: '/tmp/submersion-test');

    final container = ProviderContainer(
      overrides: rootProviderOverrides(
        prefs: prefs,
        logFileService: logFileService,
      ).cast(),
    );
    addTearDown(container.dispose);

    expect(
      container.read(clockSyncSettingsNotifierProvider).globalEnabled,
      isTrue,
    );
    await container
        .read(clockSyncSettingsNotifierProvider.notifier)
        .setGlobalEnabled(false);
    expect(prefs.getBool('dive_computer_clock_sync_enabled'), isFalse);
  });

  test('backs the viewer fullscreen mode with SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.viewerFullscreenMode: 'fullscreen',
    });
    final prefs = await SharedPreferences.getInstance();
    final logFileService = LogFileService(
      logDirectory: p.join(Directory.systemTemp.path, 'submersion-test'),
    );

    final container = ProviderContainer(
      overrides: rootProviderOverrides(
        prefs: prefs,
        logFileService: logFileService,
      ).cast(),
    );
    addTearDown(container.dispose);

    expect(
      container.read(viewerFullscreenModeProvider),
      ViewerFullscreenMode.fullscreen,
    );
    await container
        .read(viewerFullscreenModeProvider.notifier)
        .setMode(ViewerFullscreenMode.fullWindow);
    expect(prefs.getString(SettingsKeys.viewerFullscreenMode), 'fullWindow');
  });

  test('installs the process share gate when given one, so a held share '
      'outlives a soft restart (#2690)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Never initialized, so no directory is created.
    final logFileService = LogFileService(
      logDirectory: p.join(Directory.systemTemp.path, 'submersion-test'),
    );
    final shares = NavigationReadyGate<IncomingShare>();

    ProviderContainer containerWith({
      NavigationReadyGate<IncomingShare>? incomingShares,
    }) {
      final container = ProviderContainer(
        overrides: rootProviderOverrides(
          prefs: prefs,
          logFileService: logFileService,
          incomingShares: incomingShares,
        ).cast(),
      );
      addTearDown(container.dispose);
      return container;
    }

    expect(
      containerWith(incomingShares: shares).read(incomingShareGateProvider),
      same(shares),
    );
    // The safety sweep passes none and gets a gate of its own.
    expect(
      containerWith().read(incomingShareGateProvider),
      isNot(same(shares)),
    );
  });

  test('backs the media cache sizes with SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({kMediaDiskCacheMbKey: 2048});
    final prefs = await SharedPreferences.getInstance();
    final logFileService = LogFileService(
      logDirectory: p.join(Directory.systemTemp.path, 'submersion-test'),
    );

    final container = ProviderContainer(
      overrides: rootProviderOverrides(
        prefs: prefs,
        logFileService: logFileService,
      ).cast(),
    );
    addTearDown(container.dispose);

    expect(container.read(mediaCacheSettingsProvider).diskCacheMb, 2048);
    // The disk size, not the memory one: changing that would resize the
    // process-wide image cache under every other test in this isolate.
    await container
        .read(mediaCacheSettingsProvider.notifier)
        .setDiskCacheMb(4096);
    expect(prefs.getInt(kMediaDiskCacheMbKey), 4096);
  });
}
