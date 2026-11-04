import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

const String _unavailable = 'WinHTTP is native only';

/// Browser variant of the Windows resolver: the browser applies the system
/// proxy itself, so the app always sees a direct connection.
class WindowsSystemProxyResolver implements SystemProxyResolver {
  WindowsSystemProxyResolver({
    Future<RawWindowsProxy> Function()? readConfig,
    Future<RawWindowsProxy> Function(String url, RawWindowsProxy config)?
    queryPac,
    Duration timeout = const Duration(seconds: 5),
  });

  @override
  Future<SystemProxyResult> resolve(Uri probe) async => const SystemProxyNone();
}

/// Throws [UnsupportedError]: WinHTTP is not reachable from a browser.
RawWindowsProxy readIeProxyConfig() => throw UnsupportedError(_unavailable);

/// Throws [UnsupportedError]: WinHTTP is not reachable from a browser.
RawWindowsProxy queryPacForUrl(String url, RawWindowsProxy config) =>
    throw UnsupportedError(_unavailable);
