import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// What WinHTTP reported, copied out of native memory so parsing is testable.
@immutable
class RawWindowsProxy {
  const RawWindowsProxy({
    required this.autoDetect,
    this.autoConfigUrl,
    this.staticProxy,
    this.staticBypass,
    this.pacAttempted = false,
    this.pacSucceeded = false,
    this.pacProxy,
    this.pacBypass,
  });

  /// "Automatically detect settings" (WPAD).
  final bool autoDetect;

  /// "Use setup script".
  final String? autoConfigUrl;
  final String? staticProxy;
  final String? staticBypass;
  final bool pacAttempted;
  final bool pacSucceeded;

  /// WinHttpGetProxyForUrl's proxy list; null when it chose direct.
  final String? pacProxy;
  final String? pacBypass;
}

/// Turns what WinHTTP reported into the app's view of the system proxy.
SystemProxyResult parseWindowsProxy(RawWindowsProxy raw) {
  if (raw.pacAttempted && raw.pacSucceeded) {
    final pac = raw.pacProxy;
    final picked = pac == null ? null : pickWindowsProxy(pac);
    if (picked == null) return const SystemProxyNone();
    return SystemProxyFixed(
      type: picked.type,
      host: picked.host,
      port: picked.port,
      bypass: _bypass(raw.pacBypass ?? raw.staticBypass),
      viaPac: true,
    );
  }
  final staticText = raw.staticProxy;
  final fixed = staticText == null ? null : pickWindowsProxy(staticText);
  if (fixed != null) {
    return SystemProxyFixed(
      type: fixed.type,
      host: fixed.host,
      port: fixed.port,
      bypass: _bypass(raw.staticBypass),
    );
  }
  // Auto-detect alone failing means no WPAD server: the default on home
  // PCs, where "Automatically detect settings" is on. That is "no proxy".
  // A PAC URL someone configured failing is a real problem worth showing.
  final configured = raw.autoConfigUrl?.trim().isNotEmpty ?? false;
  if (raw.pacAttempted && configured) {
    return const SystemProxyUnavailable(SystemProxyUnavailableReason.pacFailed);
  }
  return const SystemProxyNone();
}

List<String> _bypass(String? value) =>
    (value ?? '').split(RegExp(r'[;\s]+')).where((e) => e.isNotEmpty).toList();

/// Picks one proxy from a WinHTTP list such as `proxy:8080` or
/// `http=a:1;https=b:2;socks=c:3`: https first, then http or unlabelled,
/// then socks.
({ProxyType type, String host, int port})? pickWindowsProxy(String list) {
  final entries = list.split(RegExp(r'[;\s]+')).where((e) => e.isNotEmpty);
  String? https;
  String? http;
  String? socks;
  for (final entry in entries) {
    final eq = entry.indexOf('=');
    if (eq < 0) {
      http ??= entry;
      continue;
    }
    final scheme = entry.substring(0, eq).toLowerCase();
    final value = entry.substring(eq + 1);
    if (scheme == 'https') https ??= value;
    if (scheme == 'http') http ??= value;
    if (scheme == 'socks') socks ??= value;
  }
  final chosen = https ?? http;
  if (chosen != null) return _endpoint(chosen, ProxyType.http, 80);
  if (socks != null) return _endpoint(socks, ProxyType.socks5, 1080);
  return null;
}

({ProxyType type, String host, int port})? _endpoint(
  String value,
  ProxyType type,
  int defaultPort,
) {
  final uri = Uri.tryParse(value.contains('://') ? value : 'x://$value');
  if (uri == null || uri.host.isEmpty) return null;
  return (
    type: type,
    host: uri.host,
    port: uri.hasPort ? uri.port : defaultPort,
  );
}
