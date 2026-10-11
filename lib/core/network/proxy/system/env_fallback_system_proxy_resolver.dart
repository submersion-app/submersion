import 'dart:io';

import 'package:submersion/core/network/proxy/system/linux_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// Uses the HTTPS_PROXY-style environment variables when the OS reports no
/// proxy configured (never when a PAC script chose DIRECT). dart:io's default
/// proxy lookup read them before AppHttpOverrides replaced it, so a
/// machine-wide variable keeps working. An OS proxy, or an OS problem worth
/// showing, wins over the environment.
class EnvFallbackSystemProxyResolver implements SystemProxyResolver {
  EnvFallbackSystemProxyResolver(
    this._inner, {
    Map<String, String>? environment,
  }) : _environment = environment ?? Platform.environment;

  final SystemProxyResolver _inner;
  final Map<String, String> _environment;

  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    final result = await _inner.resolve(probe);
    if (result is! SystemProxyNone || result.viaPac) return result;
    return parseProxyEnvironment(_environment) ?? result;
  }
}
