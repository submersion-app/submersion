import 'dart:async';
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

  static Future<String?> _runGSettings(String schema, String key) =>
      runBoundedProcess('gsettings', ['get', schema, key]);

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

/// What [executable] printed, or null when it is missing, fails, or is still
/// running after [timeout]. A stalled settings service (gsettings waits on
/// D-Bus) must not leave a process, and the status line's spinner, behind
/// every refresh, so a late process is killed.
Future<String?> runBoundedProcess(
  String executable,
  List<String> arguments, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final Process process;
  try {
    process = await Process.start(executable, arguments);
  } on ProcessException {
    // Not a GNOME desktop: no gsettings binary.
    return null;
  }
  final stdout = process.stdout.transform(systemEncoding.decoder).join();
  unawaited(process.stderr.drain<void>());
  final exitCode = await process.exitCode.timeout(
    timeout,
    onTimeout: () {
      process.kill();
      return -1;
    },
  );
  if (exitCode != 0) return null;
  return stdout;
}
