import 'package:flutter/foundation.dart';

/// How the app chooses a proxy for its own HTTP traffic.
enum ProxyMode { system, manual, none }

/// The protocol of a manual proxy.
enum ProxyType { http, socks5 }

/// The persisted proxy choice for this device.
///
/// Device-local: a proxy belongs to a device and the network it is on, not to
/// a diver, so this never syncs. The manual password is not here; it lives in
/// secure storage (ProxySettingsStore).
@immutable
class ProxySettings {
  const ProxySettings({
    required this.mode,
    required this.type,
    required this.host,
    required this.port,
    required this.username,
  });

  static const defaults = ProxySettings(
    mode: ProxyMode.system,
    type: ProxyType.http,
    host: '',
    port: null,
    username: '',
  );

  final ProxyMode mode;
  final ProxyType type;
  final String host;
  final int? port;
  final String username;

  /// Whether the manual fields describe a usable proxy.
  bool get hasManualProxy {
    final p = port;
    return host.trim().isNotEmpty && p != null && p >= 1 && p <= 65535;
  }

  ProxySettings copyWith({
    ProxyMode? mode,
    ProxyType? type,
    String? host,
    int? port,
    bool clearPort = false,
    String? username,
  }) => ProxySettings(
    mode: mode ?? this.mode,
    type: type ?? this.type,
    host: host ?? this.host,
    port: clearPort ? null : (port ?? this.port),
    username: username ?? this.username,
  );

  @override
  bool operator ==(Object other) =>
      other is ProxySettings &&
      other.mode == mode &&
      other.type == type &&
      other.host == host &&
      other.port == port &&
      other.username == username;

  @override
  int get hashCode => Object.hash(mode, type, host, port, username);
}
