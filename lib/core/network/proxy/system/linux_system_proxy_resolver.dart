import 'dart:io';

import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/linux_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// Reads one GNOME setting as gsettings prints it, or null.
typedef GSettingsReader = Future<String?> Function(String schema, String key);

/// Linux: the environment variables first (as curl reads them), then GNOME's
/// proxy settings. There is no PAC engine here, so GNOME's automatic mode is
/// reported as unsupported and the user is pointed at Manual.
class LinuxSystemProxyResolver implements SystemProxyResolver {
  LinuxSystemProxyResolver({
    Map<String, String>? environment,
    GSettingsReader? gsettings,
  }) : _environment = environment ?? Platform.environment,
       _gsettings = gsettings ?? _runGSettings;

  final Map<String, String> _environment;
  final GSettingsReader _gsettings;

  static Future<String?> _runGSettings(String schema, String key) async {
    try {
      final r = await Process.run('gsettings', ['get', schema, key]);
      return r.exitCode == 0 ? r.stdout as String : null;
    } on ProcessException {
      // Not a GNOME desktop: no gsettings binary.
      return null;
    }
  }

  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    final fromEnv = parseProxyEnvironment(_environment);
    if (fromEnv != null) return fromEnv;
    try {
      const base = 'org.gnome.system.proxy';
      final mode = parseGVariantString(await _gsettings(base, 'mode'));
      if (mode == 'auto') {
        return const SystemProxyUnavailable(
          SystemProxyUnavailableReason.pacUnsupported,
        );
      }
      if (mode != 'manual') return const SystemProxyNone();
      final bypass = parseGVariantStringList(
        await _gsettings(base, 'ignore-hosts'),
      );
      for (final (schema, type) in [
        ('$base.https', ProxyType.http),
        ('$base.http', ProxyType.http),
        ('$base.socks', ProxyType.socks5),
      ]) {
        final host = parseGVariantString(await _gsettings(schema, 'host'));
        final port = int.tryParse(
          (await _gsettings(schema, 'port'))?.trim() ?? '',
        );
        final validPort = port != null && port >= 1 && port <= 65535;
        if (host != null && host.isNotEmpty && validPort) {
          return SystemProxyFixed(
            type: type,
            host: host,
            port: port,
            bypass: bypass,
          );
        }
      }
      return const SystemProxyNone();
    } catch (e) {
      return SystemProxyUnavailable(
        SystemProxyUnavailableReason.platformError,
        detail: '$e',
      );
    }
  }
}
