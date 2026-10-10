import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/env_fallback_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

class _Fixed implements SystemProxyResolver {
  _Fixed(this.answer);

  final SystemProxyResult answer;

  @override
  Future<SystemProxyResult> resolve(Uri probe) async => answer;
}

void main() {
  final probe = Uri.parse('https://api.github.com/');
  const env = {'HTTPS_PROXY': 'http://envproxy:3128'};

  test('the environment fills in when the OS reports no proxy', () async {
    final r = await EnvFallbackSystemProxyResolver(
      _Fixed(const SystemProxyNone()),
      environment: env,
    ).resolve(probe);
    expect(
      r,
      const SystemProxyFixed(
        type: ProxyType.http,
        host: 'envproxy',
        port: 3128,
      ),
    );
  });

  test('an OS proxy or an OS problem wins over the environment', () async {
    const os = SystemProxyFixed(type: ProxyType.http, host: 'os', port: 1);
    expect(
      await EnvFallbackSystemProxyResolver(
        _Fixed(os),
        environment: env,
      ).resolve(probe),
      os,
    );
    const problem = SystemProxyUnavailable(
      SystemProxyUnavailableReason.pacFailed,
    );
    expect(
      await EnvFallbackSystemProxyResolver(
        _Fixed(problem),
        environment: env,
      ).resolve(probe),
      problem,
    );
  });

  test('a PAC script that chose direct wins over the environment', () async {
    expect(
      await EnvFallbackSystemProxyResolver(
        _Fixed(const SystemProxyNone(viaPac: true)),
        environment: env,
      ).resolve(probe),
      const SystemProxyNone(viaPac: true),
    );
  });

  test('no OS proxy and no environment is none', () async {
    expect(
      await EnvFallbackSystemProxyResolver(
        _Fixed(const SystemProxyNone()),
        environment: const {},
      ).resolve(probe),
      const SystemProxyNone(),
    );
  });
}
