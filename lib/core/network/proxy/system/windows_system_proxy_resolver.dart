import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// Windows: replaced by the WinHTTP implementation in the next change.
class WindowsSystemProxyResolver implements SystemProxyResolver {
  @override
  Future<SystemProxyResult> resolve(Uri probe) async => const SystemProxyNone();
}
