import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Everything the Network settings page shows.
@immutable
class ProxyControllerState {
  const ProxyControllerState({
    required this.settings,
    required this.system,
    required this.detecting,
    required this.effective,
  });

  final ProxySettings settings;

  /// The last OS answer; null until one arrives.
  final SystemProxyResult? system;

  /// Whether an OS lookup is in flight.
  final bool detecting;
  final EffectiveProxy effective;
}

/// Holds the proxy snapshot every new connection reads (through
/// AppHttpOverrides) and recomputes it when the settings or the network
/// change. One instance per process, made in main().
///
/// Each recompute takes a generation number; an OS answer that arrives after
/// a newer recompute started is dropped, so a slow PAC lookup can never
/// overwrite a choice the user made after it began.
class ProxyController {
  ProxyController({required SystemProxyResolver resolver, Uri? probeUrl})
    : _resolver = resolver,
      _probe = probeUrl ?? proxyProbeUrl;

  static const _log = LoggerService('Proxy');

  final SystemProxyResolver _resolver;
  final Uri _probe;
  final _changes = StreamController<ProxyControllerState>.broadcast();

  ProxySettingsStore? _store;
  String? _password;
  int _generation = 0;
  var _state = const ProxyControllerState(
    settings: ProxySettings.defaults,
    system: null,
    detecting: false,
    effective: EffectiveProxy.direct(source: ProxySource.system),
  );

  /// The snapshot for the next connection. Read synchronously per request.
  EffectiveProxy get current => _state.effective;
  ProxyControllerState get state => _state;

  /// The saved manual password, for pre-filling the form. Never logged.
  String? get manualPassword => _password;
  Stream<ProxyControllerState> get changes => _changes.stream;

  /// Loads the saved choice and, in system mode, asks the OS, waiting at most
  /// [startupTimeout] so a slow PAC server cannot hold up app launch. A late
  /// answer is applied when it arrives.
  Future<void> initialize(
    ProxySettingsStore store, {
    Duration startupTimeout = const Duration(seconds: 3),
  }) async {
    _store = store;
    final settings = store.load();
    _password = await _loadPassword(store, settings);
    await _recompute(settings).timeout(
      startupTimeout,
      onTimeout: () {
        _log.info('System proxy detection is slow; starting direct');
      },
    );
  }

  /// Persists [settings] and applies them. The password changes only when
  /// [updatePassword] is true (null or empty deletes it).
  Future<void> saveSettings(
    ProxySettings settings, {
    String? password,
    bool updatePassword = false,
  }) async {
    final store = _store;
    if (store != null) {
      await store.save(settings);
      if (updatePassword) await store.savePassword(password);
    }
    if (updatePassword) {
      _password = password == null || password.isEmpty ? null : password;
    }
    await _recompute(settings);
  }

  /// Asks the OS again (system mode) and re-applies the current settings.
  Future<void> refresh() => _recompute(_state.settings);

  Future<String?> _loadPassword(
    ProxySettingsStore store,
    ProxySettings settings,
  ) async {
    // Loaded whatever the mode: switching back to Manual later must not
    // send the saved proxy without its password.
    if (settings.username.isEmpty) return null;
    try {
      return await store.loadPassword();
    } catch (e, st) {
      _log.error('Could not read the proxy password', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> _recompute(ProxySettings settings) async {
    final generation = ++_generation;
    if (settings.mode != ProxyMode.system) {
      _apply(settings, _state.system, detecting: false);
      return;
    }
    _apply(settings, _state.system, detecting: true);
    SystemProxyResult result;
    try {
      result = await _resolver.resolve(_probe);
    } catch (e) {
      result = SystemProxyUnavailable(
        SystemProxyUnavailableReason.platformError,
        detail: '$e',
      );
    }
    if (generation != _generation) return;
    if (result is SystemProxyUnavailable) {
      _log.warning(
        'System proxy unavailable: ${result.reason.name} '
        '${result.detail ?? ''}',
      );
    }
    _apply(settings, result, detecting: false);
  }

  void _apply(
    ProxySettings settings,
    SystemProxyResult? system, {
    required bool detecting,
  }) {
    final effective = EffectiveProxy.resolve(
      settings: settings,
      system: system,
      password: _password,
    );
    if (effective != _state.effective) _log.info('Proxy now $effective');
    _state = ProxyControllerState(
      settings: settings,
      system: system,
      detecting: detecting,
      effective: effective,
    );
    if (!_changes.isClosed) _changes.add(_state);
  }

  void dispose() => _changes.close();
}
