import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/agent_access/data/agent_access_token_store.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server.dart';
import 'package:submersion/features/agent_access/presentation/providers/agent_access_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

Future<void> pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue, reason: 'condition not met within 5 s');
}

void main() {
  late InMemoryKeychain keychain;

  setUp(() async {
    await setUpTestDatabase();
    keychain = InMemoryKeychain();
  });

  tearDown(() async {
    await AgentAccessServer.instance.stop();
    await tearDownTestDatabase();
    debugDefaultTargetPlatformOverride = null;
    applyGlobalTestDefaults();
  });

  Future<ProviderContainer> container({TargetPlatform? platform}) async {
    debugDefaultTargetPlatformOverride = platform;
    final base = await getBaseOverrides();
    final c = ProviderContainer(
      overrides: [
        ...base,
        agentAccessTokenStoreProvider.overrideWithValue(
          AgentAccessTokenStore(storage: keychain),
        ),
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'Submersion',
            packageName: 'app.submersion',
            version: '1.2.3',
            buildNumber: '7',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('agentAccessSettingsProvider', () {
    test('reads defaults and persists changes', () async {
      final c = await container();
      expect(c.read(agentAccessSettingsProvider).enabled, isFalse);
      await c.read(agentAccessSettingsProvider.notifier).setPort(50123);
      await c
          .read(agentAccessSettingsProvider.notifier)
          .setConfirmWrites(false);
      expect(c.read(agentAccessSettingsProvider).port, 50123);
      expect(c.read(agentAccessSettingsProvider).confirmWrites, isFalse);
      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getInt('agent_access_port'), 50123);
      expect(prefs.getBool('agent_access_confirm_writes'), isFalse);
    });
  });

  group('agentAccessControllerProvider', () {
    test(
      'starts the server when enabled on desktop and stops when disabled',
      () async {
        final c = await container(platform: TargetPlatform.macOS);
        c.read(agentAccessControllerProvider);
        await c.read(agentAccessSettingsProvider.notifier).setPort(0);
        await c.read(agentAccessSettingsProvider.notifier).setEnabled(true);
        await pumpUntil(() => AgentAccessServer.instance.status.listening);
        expect(keychain.values[AgentAccessTokenStore.key], isNotNull);
        await c.read(agentAccessSettingsProvider.notifier).setEnabled(false);
        await pumpUntil(() => !AgentAccessServer.instance.status.listening);
      },
    );

    test('never starts on a non-desktop platform', () async {
      final c = await container(platform: TargetPlatform.android);
      c.read(agentAccessControllerProvider);
      await c.read(agentAccessSettingsProvider.notifier).setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(AgentAccessServer.instance.status.listening, isFalse);
    });

    test('disposing the container stops the server', () async {
      final c = await container(platform: TargetPlatform.macOS);
      c.read(agentAccessControllerProvider);
      await c.read(agentAccessSettingsProvider.notifier).setPort(0);
      await c.read(agentAccessSettingsProvider.notifier).setEnabled(true);
      await pumpUntil(() => AgentAccessServer.instance.status.listening);
      c.dispose();
      await pumpUntil(() => !AgentAccessServer.instance.status.listening);
    });

    test('regenerateToken rotates the stored token', () async {
      final c = await container(platform: TargetPlatform.macOS);
      final controller = c.read(agentAccessControllerProvider);
      final first = await c.read(agentAccessTokenStoreProvider).ensure();
      final second = await controller.regenerateToken();
      expect(second, isNot(first));
      expect(keychain.values[AgentAccessTokenStore.key], second);
    });
  });

  group('agentAccessStatusProvider', () {
    test('mirrors the server status stream', () async {
      final c = await container(platform: TargetPlatform.macOS);
      c.listen(agentAccessStatusProvider, (_, _) {});
      await c.read(agentAccessStatusProvider.future);
      c.read(agentAccessControllerProvider);
      await c.read(agentAccessSettingsProvider.notifier).setPort(0);
      await c.read(agentAccessSettingsProvider.notifier).setEnabled(true);
      await pumpUntil(
        () => c.read(agentAccessStatusProvider).value?.listening == true,
      );
      expect(
        c.read(agentAccessStatusProvider).value!.url,
        startsWith('http://127.0.0.1:'),
      );
    });
  });
}
