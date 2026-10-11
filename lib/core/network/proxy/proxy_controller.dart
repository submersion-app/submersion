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
  bool _passwordLoaded = false;
  int _generation = 0;
  Future<void> _writes = Future.value();
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
    await _recompute(settings).timeout(
      startupTimeout,
      onTimeout: () {
        _log.info('System proxy detection is slow; starting direct');
      },
    );
  }

  /// Persists [settings] and applies them. The password changes only when
  /// [updatePassword] is true (null or empty deletes it).
  ///
  /// The storage writes run one at a time in the order the saves were made,
  /// so a slow write can never let an older choice land after a newer one.
  /// Only the writes queue: each save's recompute starts after its writes,
  /// in the same order, and a newer one supersedes it as usual.
  Future<void> saveSettings(
    ProxySettings settings, {
    String? password,
    bool updatePassword = false,
  }) async {
    final writes = _writes.then(
      (_) => _persist(settings, password, updatePassword: updatePassword),
    );
    _writes = writes.catchError((Object _) {});
    await writes;
    if (updatePassword) {
      _password = password == null || password.isEmpty ? null : password;
      _passwordLoaded = true;
    }
    await _recompute(settings);
  }

  Future<void> _persist(
    ProxySettings settings,
    String? password, {
    required bool updatePassword,
  }) async {
    final store = _store;
    if (store == null) return;
    // The password first: when the keychain refuses it (locked), the saved
    // settings stay as they were, so a restart never loads Manual without
    // the password that goes with it.
    if (updatePassword) await store.savePassword(password);
    await store.save(settings);
  }

  /// Asks the OS again (system mode) and re-applies the current settings.
  Future<void> refresh() => _recompute(_state.settings);

  Future<String?> _loadPassword(
    ProxySettingsStore store,
    ProxySettings settings,
  ) async {
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
    // The keychain is read the first time Manual applies, not at startup:
    // System and No proxy never use the password, and the read would sit
    // before the first frame.
    final store = _store;
    if (settings.mode == ProxyMode.manual &&
        !_passwordLoaded &&
        store != null) {
      final loaded = await _loadPassword(store, settings);
      // A newer recompute owns the password now: a Save may have set it
      // while this read was in flight, and the read holds the old value.
      if (generation != _generation) return;
      _password = loaded;
      _passwordLoaded = true;
    }
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
