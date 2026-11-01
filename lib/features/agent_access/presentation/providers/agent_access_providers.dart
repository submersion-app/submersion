import 'dart:async';

import 'package:mcp_dart/mcp_dart.dart' show McpServer;

import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
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
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final agentAccessPreferencesProvider = Provider<AgentAccessPreferences>(
  (ref) => AgentAccessPreferences(ref.watch(sharedPreferencesProvider)),
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

  Future<void> _update(AgentAccessSettings next) async {
    state = next;
    await ref.read(agentAccessPreferencesProvider).write(next);
  }
}

final agentAccessTokenStoreProvider = Provider<AgentAccessTokenStore>(
  (ref) => AgentAccessTokenStore(),
);

/// The listener's status, for the settings page.
final agentAccessStatusProvider = StreamProvider<AgentAccessStatus>((
  ref,
) async* {
  yield AgentAccessServer.instance.status;
  yield* AgentAccessServer.instance.statusStream;
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
  unawaited(controller.sync());
  ref.onDispose(() => unawaited(AgentAccessServer.instance.stop()));
  return controller;
});

class AgentAccessController {
  AgentAccessController(this._ref);

  final Ref _ref;
  Future<void> _queue = Future.value();
  String? _token;

  /// Brings the server in line with the current settings. Calls are
  /// serialised so a burst of settings changes never interleaves starts
  /// and stops.
  Future<void> sync() {
    final next = _queue.then((_) => _syncOnce());
    _queue = next.catchError((_) {});
    return next;
  }

  /// Rotates the bearer token. Running sessions see the new token on their
  /// next request because the server reads it through [_token].
  Future<String> regenerateToken() async {
    final token = await _ref.read(agentAccessTokenStoreProvider).regenerate();
    _token = token;
    return token;
  }

  Future<void> _syncOnce() async {
    final settings = _ref.read(agentAccessSettingsProvider);
    final server = AgentAccessServer.instance;
    if (!settings.enabled || !hasDesktopWindow()) {
      await server.stop();
      return;
    }
    // Tools read diver unit preferences; before the first load those are
    // placeholders.
    await awaitCurrentDiverSettings(_ref);
    _token = await _ref.read(agentAccessTokenStoreProvider).ensure();
    final status = server.status;
    if (status.listening && status.port == settings.port) return;
    final appVersion = await _appVersion();
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
