import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/proxy_credentials.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

enum ProxyKind { direct, http, socks5 }

/// Where the snapshot came from, for the settings page and the log.
enum ProxySource { none, manual, system, systemPac }

/// The proxy every new connection uses right now. Immutable: the network
/// layer reads one snapshot per connection and never sees a half update.
@immutable
class EffectiveProxy {
  const EffectiveProxy({
    required this.kind,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.bypass = const [],
    required this.source,
  });

  const EffectiveProxy.direct({this.source = ProxySource.none})
    : kind = ProxyKind.direct,
      host = '',
      port = 0,
      username = null,
      password = null,
      bypass = const [];

  final ProxyKind kind;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final List<String> bypass;
  final ProxySource source;

  bool get isDirect => kind == ProxyKind.direct;

  /// `host:port`, with an IPv6 host in brackets.
  String get endpoint => host.contains(':') ? '[$host]:$port' : '$host:$port';

  /// The snapshot for [settings], given the OS answer [system] (null until
  /// one arrives) and the manual [password].
  static EffectiveProxy resolve({
    required ProxySettings settings,
    SystemProxyResult? system,
    String? password,
  }) {
    switch (settings.mode) {
      case ProxyMode.none:
        return const EffectiveProxy.direct();
      case ProxyMode.manual:
        if (!settings.hasManualProxy) {
          return const EffectiveProxy.direct(source: ProxySource.manual);
        }
        final user = settings.username;
        final pass = password ?? '';
        // Credentials the transport cannot carry are dropped rather than
        // sent malformed; the form refuses to save them in the first place.
        final usable =
            user.isNotEmpty &&
            checkProxyCredentials(settings.type, user, pass) == null;
        return EffectiveProxy(
          kind: settings.type == ProxyType.http
              ? ProxyKind.http
              : ProxyKind.socks5,
          host: settings.host.trim(),
          port: settings.port!,
          username: usable ? user : null,
          password: usable ? pass : null,
          source: ProxySource.manual,
        );
      case ProxyMode.system:
        return switch (system) {
          SystemProxyFixed(:final type, :final host, :final port) =>
            EffectiveProxy(
              kind: type == ProxyType.http ? ProxyKind.http : ProxyKind.socks5,
              host: host,
              port: port,
              // Only the Linux environment carries these, unchecked; values
              // the directive cannot represent would make dart:io reject
              // every request, so they are dropped.
              username: _usableSystemCredentials(system)
                  ? system.username
                  : null,
              password: _usableSystemCredentials(system)
                  ? system.password
                  : null,
              bypass: system.bypass,
              source: system.viaPac
                  ? ProxySource.systemPac
                  : ProxySource.system,
            ),
          _ => const EffectiveProxy.direct(source: ProxySource.system),
        };
    }
  }

  static bool _usableSystemCredentials(SystemProxyFixed system) {
    final user = system.username;
    if (user == null || user.isEmpty) return false;
    return checkProxyCredentials(system.type, user, system.password ?? '') ==
        null;
  }

  @override
  bool operator ==(Object other) =>
      other is EffectiveProxy &&
      other.kind == kind &&
      other.host == host &&
      other.port == port &&
      other.username == username &&
      other.password == password &&
      listEquals(other.bypass, bypass) &&
      other.source == source;

  @override
  int get hashCode => Object.hash(
    kind,
    host,
    port,
    username,
    password,
    Object.hashAll(bypass),
    source,
  );

  /// Never includes the credentials: this string reaches the debug log.
  @override
  String toString() => isDirect
      ? 'EffectiveProxy(direct, ${source.name})'
      : 'EffectiveProxy(${kind.name} $endpoint, ${source.name}, '
            'auth: ${username != null}, bypass: ${bypass.length})';
}
