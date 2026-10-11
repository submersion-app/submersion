import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/written_proxy_port.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// The proxy named by the curl-style environment variables, or null.
///
/// Order: https_proxy, HTTPS_PROXY, http_proxy, HTTP_PROXY, all_proxy,
/// ALL_PROXY; no_proxy (or NO_PROXY) is the bypass list.
SystemProxyResult? parseProxyEnvironment(Map<String, String> env) {
  const keys = [
    'https_proxy',
    'HTTPS_PROXY',
    'http_proxy',
    'HTTP_PROXY',
    'all_proxy',
    'ALL_PROXY',
  ];
  for (final key in keys) {
    final value = env[key]?.trim();
    if (value == null || value.isEmpty) continue;
    final parsed = _parseProxyUrl(value);
    if (parsed == null) continue;
    return SystemProxyFixed(
      type: parsed.type,
      host: parsed.host,
      port: parsed.port,
      bypass: parseNoProxy(env['no_proxy'] ?? env['NO_PROXY']),
      username: parsed.username,
      password: parsed.password,
    );
  }
  return null;
}

/// Splits a comma-separated no_proxy value.
List<String> parseNoProxy(String? value) => (value ?? '')
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

({ProxyType type, String host, int port, String? username, String? password})?
_parseProxyUrl(String value) {
  final withScheme = value.contains('://') ? value : 'http://$value';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  final ProxyType type;
  final int defaultPort;
  switch (uri.scheme) {
    case 'http':
    case 'https':
      type = ProxyType.http;
      defaultPort = 80;
    case 'socks5':
    case 'socks5h':
    case 'socks':
      type = ProxyType.socks5;
      defaultPort = 1080;
    default:
      return null;
  }
  final written = writtenProxyPort(value);
  if (written.written && written.port == null) return null;
  String? user;
  String? pass;
  if (uri.userInfo.isNotEmpty) {
    final i = uri.userInfo.indexOf(':');
    try {
      user = Uri.decodeComponent(
        i < 0 ? uri.userInfo : uri.userInfo.substring(0, i),
      );
      pass = i < 0 ? null : Uri.decodeComponent(uri.userInfo.substring(i + 1));
    } on FormatException {
      // A bad escape (%FF) makes this one value unusable, not the list.
      return null;
    } on ArgumentError {
      return null;
    }
  }
  return (
    type: type,
    host: uri.host,
    port: written.port ?? defaultPort,
    username: user,
    password: pass,
  );
}

/// `'manual'` (gsettings' printed GVariant string) to `manual`.
String? parseGVariantString(String? out) {
  final t = out?.trim();
  if (t == null || t.length < 2) return null;
  if (t.startsWith("'") && t.endsWith("'")) {
    return t.substring(1, t.length - 1);
  }
  return t;
}

/// `['a', 'b']` or `@as []` to a list.
List<String> parseGVariantStringList(String? out) {
  final t = out?.trim() ?? '';
  final start = t.indexOf('[');
  final end = t.lastIndexOf(']');
  if (start < 0 || end <= start) return const [];
  return RegExp(r"'([^']*)'")
      .allMatches(t.substring(start + 1, end))
      .map((m) => m.group(1)!)
      .where((e) => e.isNotEmpty)
      .toList();
}
