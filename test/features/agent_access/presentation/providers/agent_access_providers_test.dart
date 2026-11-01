import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/agent_access/data/agent_access_token_store.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server.dart';
import 'package:submersion/features/agent_access/presentation/providers/agent_access_providers.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

/// Debug mode as a plain flag: the real notifier also reconfigures the
/// file logger, which is process-wide state a test must not touch.
class _FakeDebugMode extends DebugModeNotifier {
  _FakeDebugMode(super.prefs, super.logFileService, {required bool on}) {
    state = on;
  }

  @override
  Future<void> enable() async => state = true;

  @override
  Future<void> disable() async => state = false;
}

/// A keychain that answers slowly, so a rotation can race a start.
class _SlowKeychain extends InMemoryKeychain {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return values[key];
  }
}

/// A keychain whose every operation fails, like a locked or absent store.
class _ThrowingKeychain extends InMemoryKeychain {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw StateError('keychain down');
}

Future<void> pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  final status = AgentAccessServer.instance.status;
  expect(
    condition(),
    isTrue,
    reason:
        'condition not met within 10 s; listening=${status.listening} '
        'port=${status.port} error=${status.error}',
  );
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

  /// Reads the controller and keeps it alive with a listener, as the app
  /// root does with listenManual; a provider nobody listens to is paused by
  /// Riverpod and its own ref.listen subscriptions stop firing.
  AgentAccessController startController(ProviderContainer c) {
    c.listen(agentAccessControllerProvider, (_, _) {});
    return c.read(agentAccessControllerProvider);
  }

  Future<ProviderContainer> container({
    TargetPlatform? platform,
    bool debugMode = true,
    FlutterSecureStorage? storage,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    final base = await getBaseOverrides();
    final logFiles = LogFileService(logDirectory: Directory.systemTemp.path);
    final c = ProviderContainer(
      overrides: [
        ...base,
        logFileServiceProvider.overrideWithValue(logFiles),
        debugModeNotifierProvider.overrideWith(
          (ref) => _FakeDebugMode(
            ref.watch(sharedPreferencesProvider),
            logFiles,
            on: debugMode,
          ),
        ),
        agentAccessTokenStoreProvider.overrideWithValue(
          AgentAccessTokenStore(storage: storage ?? keychain),
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
    test('rapid changes reach the preferences in order', () async {
      final c = await container();
      final notifier = c.read(agentAccessSettingsProvider.notifier);
      final first = notifier.setPort(50001);
      final second = notifier.setEnabled(true);
      final third = notifier.setPort(50002);
      await Future.wait([first, second, third]);
      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getInt('agent_access_port'), 50002);
      expect(prefs.getBool('agent_access_enabled'), isTrue);
      expect(c.read(agentAccessSettingsProvider).port, 50002);
    });

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
        startController(c);
        await c.read(agentAccessSettingsProvider.notifier).setPort(0);
        await c.read(agentAccessSettingsProvider.notifier).setEnabled(true);
        await pumpUntil(() => AgentAccessServer.instance.status.listening);
        expect(keychain.values[AgentAccessTokenStore.key], isNotNull);
        await c.read(agentAccessSettingsProvider.notifier).setEnabled(false);
        await pumpUntil(() => !AgentAccessServer.instance.status.listening);
      },
    );

    test('never starts while debug mode is off', () async {
      final c = await container(
        platform: TargetPlatform.macOS,
        debugMode: false,
      );
      startController(c);
      await c.read(agentAccessSettingsProvider.notifier).setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(AgentAccessServer.instance.status.listening, isFalse);
    });

    test('turning debug mode off stops a running server', () async {
      final c = await container(platform: TargetPlatform.macOS);
      startController(c);
      await c.read(agentAccessSettingsProvider.notifier).setPort(0);
      await c.read(agentAccessSettingsProvider.notifier).setEnabled(true);
      await pumpUntil(() => AgentAccessServer.instance.status.listening);
      await c.read(debugModeNotifierProvider.notifier).disable();
      await pumpUntil(() => !AgentAccessServer.instance.status.listening);
    });

    test(
      'a rotation during a slow start wins over the token being read',
      () async {
        final slow = _SlowKeychain()..values[AgentAccessTokenStore.key] = 'old';
        final c = await container(
          platform: TargetPlatform.macOS,
          storage: slow,
        );
        final controller = startController(c);
        await c.read(agentAccessSettingsProvider.notifier).setPort(0);
        final enabling = c
            .read(agentAccessSettingsProvider.notifier)
            .setEnabled(true);
        final rotated = await controller.regenerateToken();
        await enabling;
        await pumpUntil(() => AgentAccessServer.instance.status.listening);
        await controller.sync();
        expect(rotated, isNot('old'));
        expect(controller.currentToken, rotated);
        expect(slow.values[AgentAccessTokenStore.key], rotated);
      },
    );

    test('a scope disposed mid-start leaves no listener behind', () async {
      final slow = _SlowKeychain();
      final c = await container(platform: TargetPlatform.macOS, storage: slow);
      startController(c);
      await c.read(agentAccessSettingsProvider.notifier).setPort(0);
      final enabling = c
          .read(agentAccessSettingsProvider.notifier)
          .setEnabled(true);
      c.dispose();
      await enabling;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final status = AgentAccessServer.instance.status;
      expect(status.listening, isFalse);
      // The abandoned start must not leave a "could not start" error for
      // the next scope's settings page to show either.
      expect(status.error, isNull);
    });

    test('never starts on a non-desktop platform', () async {
      final c = await container(platform: TargetPlatform.android);
      startController(c);
      await c.read(agentAccessSettingsProvider.notifier).setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(AgentAccessServer.instance.status.listening, isFalse);
    });

    test('disposing the container stops the server', () async {
      final c = await container(platform: TargetPlatform.macOS);
      startController(c);
      await c.read(agentAccessSettingsProvider.notifier).setPort(0);
      await c.read(agentAccessSettingsProvider.notifier).setEnabled(true);
      await pumpUntil(() => AgentAccessServer.instance.status.listening);
      c.dispose();
      await pumpUntil(() => !AgentAccessServer.instance.status.listening);
    });

    test('a token store failure surfaces as a status error', () async {
      final broken = await container(
        platform: TargetPlatform.macOS,
        storage: _ThrowingKeychain(),
      );
      startController(broken);
      await broken.read(agentAccessSettingsProvider.notifier).setPort(0);
      await broken.read(agentAccessSettingsProvider.notifier).setEnabled(true);
      await pumpUntil(() => AgentAccessServer.instance.status.error != null);
      final status = AgentAccessServer.instance.status;
      expect(status.listening, isFalse);
      expect(status.portInUse, isFalse);
      expect(status.error, contains('keychain down'));
    });

    test('regenerateToken rotates the stored token', () async {
      final c = await container(platform: TargetPlatform.macOS);
      final controller = startController(c);
      final first = await c.read(agentAccessTokenStoreProvider).ensure();
      final second = await controller.regenerateToken();
      expect(second, isNot(first));
      expect(keychain.values[AgentAccessTokenStore.key], second);
    });
  });

  group('agentAccessStatusProvider', () {
    test(
      'delivers a status published right after it is first listened to',
      () async {
        final c = await container(platform: TargetPlatform.macOS);
        c.listen(agentAccessStatusProvider, (_, _) {});
        AgentAccessServer.instance.publishError('published early');
        await pumpUntil(
          () =>
              c.read(agentAccessStatusProvider).value?.error ==
              'published early',
        );
      },
    );

    test('mirrors the server status stream', () async {
      final c = await container(platform: TargetPlatform.macOS);
      c.listen(agentAccessStatusProvider, (_, _) {});
      await c.read(agentAccessStatusProvider.future);
      startController(c);
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
