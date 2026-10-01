import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/services/incoming_share.dart';
import 'package:submersion/shared/services/navigation_ready_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
