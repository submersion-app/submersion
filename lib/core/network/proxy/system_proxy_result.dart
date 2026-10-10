import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/proxy_settings.dart';

/// What the operating system says the app should use for internet traffic.
sealed class SystemProxyResult {
  const SystemProxyResult();
}

/// The OS goes direct.
class SystemProxyNone extends SystemProxyResult {
  const SystemProxyNone();

  @override
  bool operator ==(Object other) => other is SystemProxyNone;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'SystemProxyNone()';
}

/// The OS names one proxy, either configured outright or chosen by a PAC
/// script for the probe URL ([viaPac]).
@immutable
class SystemProxyFixed extends SystemProxyResult {
  const SystemProxyFixed({
    required this.type,
    required this.host,
    required this.port,
    this.bypass = const [],
    this.viaPac = false,
    this.username,
    this.password,
  });

  final ProxyType type;
  final String host;
  final int port;
  final List<String> bypass;
  final bool viaPac;

  /// Only the Linux environment variables can carry these.
  final String? username;
  final String? password;

  @override
  bool operator ==(Object other) =>
      other is SystemProxyFixed &&
      other.type == type &&
      other.host == host &&
      other.port == port &&
      listEquals(other.bypass, bypass) &&
      other.viaPac == viaPac &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(
    type,
    host,
    port,
    Object.hashAll(bypass),
    viaPac,
    username,
    password,
  );

  /// Never includes the credentials: this string can reach the debug log.
  @override
  String toString() =>
      'SystemProxyFixed(${type.name} $host:$port, pac: $viaPac, '
      'bypass: ${bypass.length}, auth: ${username != null})';
}

enum SystemProxyUnavailableReason { pacUnsupported, pacFailed, platformError }

/// The OS proxy could not be determined; the app goes direct and says why.
@immutable
class SystemProxyUnavailable extends SystemProxyResult {
  const SystemProxyUnavailable(this.reason, {this.detail});

  final SystemProxyUnavailableReason reason;
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is SystemProxyUnavailable &&
      other.reason == reason &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(reason, detail);

  @override
  String toString() => 'SystemProxyUnavailable(${reason.name}, $detail)';
}
