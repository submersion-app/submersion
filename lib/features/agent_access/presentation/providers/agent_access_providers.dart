import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mcp_dart/mcp_dart.dart' show McpServer;

import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/agent_access/data/agent_access_preferences.dart';
import 'package:submersion/features/agent_access/data/agent_access_token_store.dart';
import 'package:submersion/features/agent_access/data/agent_tool_gate.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server.dart';
import 'package:submersion/features/agent_access/data/server/mcp_server_builder.dart';
import 'package:submersion/features/agent_access/data/tools/agent_tool_registry.dart';
import 'package:submersion/features/agent_access/domain/agent_access_settings.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final agentAccessPreferencesProvider = Provider<AgentAccessPreferences>(
  (ref) => AgentAccessPreferences(ref.watch(sharedPreferencesProvider)),
);

/// Whether agent access exists on this device at all: desktop only, and,
/// until the write surface lands, only while debug mode is on. The Data
/// tools row and the server lifecycle both read this, so the final write PR
/// removes the debug clause in one place.
final agentAccessAvailableProvider = Provider<bool>(
  (ref) => hasDesktopWindow() && ref.watch(debugModeNotifierProvider),
);

/// The per-device agent access settings, persisted on every change.
final agentAccessSettingsProvider =
    NotifierProvider<AgentAccessSettingsNotifier, AgentAccessSettings>(
      AgentAccessSettingsNotifier.new,
    );

class AgentAccessSettingsNotifier extends Notifier<AgentAccessSettings> {
  @override
  AgentAccessSettings build() =>
      ref.watch(agentAccessPreferencesProvider).read();

  Future<void> setEnabled(bool enabled) =>
      _update(state.copyWith(enabled: enabled));

  Future<void> setPort(int port) => _update(state.copyWith(port: port));

  Future<void> setConfirmWrites(bool confirm) =>
      _update(state.copyWith(confirmWrites: confirm));

  /// Writes are chained so a burst of changes reaches disk in the order the
  /// state took them; the last write always carries the newest snapshot.
  Future<void> _writes = Future.value();

  Future<void> _update(AgentAccessSettings next) {
    state = next;
    final prefs = ref.read(agentAccessPreferencesProvider);
    final write = _writes.then((_) => prefs.write(next));
    _writes = write.then((_) {}, onError: (_) {});
    return write;
  }
}

final agentAccessTokenStoreProvider = Provider<AgentAccessTokenStore>(
  (ref) => AgentAccessTokenStore(),
);

/// The stored token, or null until the server has been enabled once. Only
/// the controller creates tokens; the settings page watches this and the
/// controller invalidates it after an ensure or a rotation.
final agentAccessTokenProvider = FutureProvider<String?>(
  (ref) => ref.watch(agentAccessTokenStoreProvider).read(),
);

/// The listener's status, for the settings page.
final agentAccessStatusProvider = StreamProvider<AgentAccessStatus>((ref) {
  // Subscribe before emitting the current value, so a status published in
  // between is never lost (an async* generator subscribes only after its
  // first yield is consumed).
  final server = AgentAccessServer.instance;
  final out = StreamController<AgentAccessStatus>();
  final sub = server.statusStream.listen(out.add);
  out.add(server.status);
  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(out.close());
  });
  return out.stream;
});

// no-tick: a long-lived service controller; it reads no table itself and
// the tools it builds resolve the database per request.
/// Keeps the MCP listener in step with the settings: on while enabled on a
/// desktop platform, off otherwise, restarted when the port changes.
///
/// Read once from the app root so it lives with the `ProviderScope`; its
/// dispose stops the server, and the process-wide [AgentAccessServer]
/// makes the next scope's start wait for that stop.
final agentAccessControllerProvider = Provider<AgentAccessController>((ref) {
  final controller = AgentAccessController(ref);
  ref.listen<AgentAccessSettings>(
    agentAccessSettingsProvider,
    (_, _) => unawaited(controller.sync()),
  );
  ref.listen<bool>(
    agentAccessAvailableProvider,
    (_, _) => unawaited(controller.sync()),
  );
  unawaited(controller.sync());
  ref.onDispose(() {
    controller.dispose();
    unawaited(AgentAccessServer.instance.stop());
  });
  return controller;
});

class AgentAccessController {
  AgentAccessController(this._ref);

  static const _log = LoggerService('AgentAccess');

  final Ref _ref;
  Future<void> _queue = Future.value();
  String? _token;
  bool _disposed = false;

  /// Called when the owning provider is disposed (a scope rebuild). A sync
  /// still awaiting the keychain, the settings or the package info resumes
  /// afterwards, sees this, and stops short of starting a listener the old
  /// scope would own or reading through a disposed Ref.
  void dispose() => _disposed = true;

  /// Brings the server in line with the current settings. Calls are
  /// serialised so a burst of settings changes never interleaves starts
  /// and stops.
  Future<void> sync() {
    final next = _queue.then((_) => _guardedSync());
    _queue = next;
    return next;
  }

  /// A failure anywhere in [_syncOnce] (the keychain refusing the token, a
  /// bind error the server did not classify) must reach the settings page
  /// and the log; the diver's one action on this feature never fails quietly.
  Future<void> _guardedSync() async {
    try {
      await _syncOnce();
    } catch (e, stackTrace) {
      _log.error(
        'Agent access could not start',
        error: e,
        stackTrace: stackTrace,
      );
      AgentAccessServer.instance.publishError(
        'Could not start agent access: $e',
      );
    }
  }

  /// The token the running server accepts, for tests.
  @visibleForTesting
  String? get currentToken => _token;

  /// Rotates the bearer token. Running sessions see the new token on their
  /// next request because the server reads it through [_token]. The
  /// rotation takes its turn in the same queue as [sync], so a start that
  /// is still reading the old token can never assign it back afterwards.
  Future<String> regenerateToken() {
    final next = _queue.then((_) async {
      final token = await _ref.read(agentAccessTokenStoreProvider).regenerate();
      _token = token;
      if (!_disposed) _ref.invalidate(agentAccessTokenProvider);
      return token;
    });
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _syncOnce() async {
    if (_disposed) return;
    final settings = _ref.read(agentAccessSettingsProvider);
    final server = AgentAccessServer.instance;
    if (!settings.enabled || !_ref.read(agentAccessAvailableProvider)) {
      await server.stop();
      return;
    }
    // Tools read diver unit preferences; before the first load those are
    // placeholders.
    await awaitCurrentDiverSettings(_ref);
    if (_disposed) return;
    final String token;
    try {
      token = await _ref.read(agentAccessTokenStoreProvider).ensure();
    } catch (e) {
      throw StateError('Could not read the access token: $e');
    }
    if (_disposed) return;
    final hadToken = _token != null;
    _token = token;
    if (!hadToken) _ref.invalidate(agentAccessTokenProvider);
    final status = server.status;
    if (status.listening && status.port == settings.port) return;
    final appVersion = await _appVersion();
    if (_disposed) return;
    await server.start(
      port: settings.port,
      token: () => _token ?? '',
      serverFactory: () => _buildServer(appVersion),
    );
  }

  Future<String> _appVersion() async {
    try {
      return (await _ref.read(packageInfoProvider.future)).version;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Runs once per MCP session (or per request on the stateless protocol),
  /// so everything here is cheap and nothing touches the database until a
  /// tool runs.
  McpServer _buildServer(String appVersion) {
    final divers = _ref.read(diverRepositoryProvider);
    final settings = _ref.read(diverSettingsRepositoryProvider);
    final loader = DiverContextLoader(
      db: () => DatabaseService.instance.database,
      divers: divers,
      settings: settings,
      localeTag: _ref.read(localeProvider),
      activeDiverId: () => _ref.read(validatedCurrentDiverIdProvider.future),
    );
    return buildMcpServer(
      registry: AgentToolRegistry.standard(
        loader: loader,
        divers: divers,
        settings: settings,
        dives: _ref.read(diveRepositoryProvider),
        buddies: _ref.read(buddyRepositoryProvider),
        species: _ref.read(speciesRepositoryProvider),
        media: _ref.read(mediaRepositoryProvider),
        diveTypes: _ref.read(diveTypeRepositoryProvider),
      ),
      gate: AgentToolGate(isLocked: () => _ref.read(appLockNotifierProvider)),
      appVersion: appVersion,
    );
  }
}
