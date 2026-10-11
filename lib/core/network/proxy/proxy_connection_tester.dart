import 'dart:async';
import 'dart:io';

import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_routing.dart';
import 'package:submersion/core/network/proxy/socks5_connector.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/services/logger_service.dart';

/// [text] with any `PROXY user:pass@` credentials masked, for error text
/// that reaches the screen or the log.
String redactProxyCredentials(String text) =>
    text.replaceAll(RegExp(r'PROXY \S*@'), 'PROXY ***@');

/// How a connection test ended.
sealed class ProxyTestOutcome {
  const ProxyTestOutcome();
}

class ProxyTestSuccess extends ProxyTestOutcome {
  const ProxyTestSuccess(this.elapsed, this.via);

  final Duration elapsed;
  final EffectiveProxy via;
}

class ProxyTestUnreachable extends ProxyTestOutcome {
  const ProxyTestUnreachable(this.endpoint);

  /// The proxy's `host:port`.
  final String endpoint;
}

class ProxyTestAuthRejected extends ProxyTestOutcome {
  const ProxyTestAuthRejected();
}

class ProxyTestTlsFailure extends ProxyTestOutcome {
  const ProxyTestTlsFailure();
}

class ProxyTestTimeout extends ProxyTestOutcome {
  const ProxyTestTimeout();
}

class ProxyTestFailed extends ProxyTestOutcome {
  const ProxyTestFailed(this.detail);

  final String detail;
}

/// One HEAD request with a throwaway client built from a snapshot, which may
/// come from unsaved form values, so a user can check a proxy before
/// committing to it. Any HTTP response at all counts as success: the route
/// works, whatever the server thinks of the request.
class ProxyConnectionTester {
  ProxyConnectionTester({
    Uri? probeUrl,
    Duration timeout = const Duration(seconds: 10),
    ProxyRoutingPolicy shouldProxy = defaultShouldProxy,
  }) : _probe = probeUrl ?? proxyProbeUrl,
       _timeout = timeout,
       _shouldProxy = shouldProxy;

  static const _log = LoggerService('ProxyTest');

  final Uri _probe;
  final Duration _timeout;
  final ProxyRoutingPolicy _shouldProxy;

  Future<ProxyTestOutcome> run(EffectiveProxy proxy) async {
    final client = AppHttpOverrides(
      currentProxy: () => proxy,
      shouldProxy: _shouldProxy,
    ).createHttpClient(null)..connectionTimeout = _timeout;
    final watch = Stopwatch()..start();
    try {
      final status = await () async {
        final request = await client.headUrl(_probe);
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      }().timeout(_timeout);
      if (status == HttpStatus.proxyAuthenticationRequired) {
        return const ProxyTestAuthRejected();
      }
      return ProxyTestSuccess(watch.elapsed, proxy);
    } catch (e, st) {
      // The error text is redacted, not attached: a dart:io directive error
      // quotes the directive, credentials included.
      _log.warning(
        'Proxy test failed via $proxy: ${redactProxyCredentials('$e')}',
        stackTrace: st,
      );
      return _classify(e, proxy);
    } finally {
      client.close(force: true);
    }
  }

  ProxyTestOutcome _classify(Object e, EffectiveProxy proxy) {
    if (e is TimeoutException) return const ProxyTestTimeout();
    if (e is Socks5Exception) {
      return switch (e.failure) {
        Socks5Failure.proxyUnreachable => ProxyTestUnreachable(proxy.endpoint),
        Socks5Failure.handshakeTimeout => const ProxyTestTimeout(),
        Socks5Failure.authRejected ||
        Socks5Failure.noAcceptableAuth => const ProxyTestAuthRejected(),
        _ => ProxyTestFailed(redactProxyCredentials(e.message)),
      };
    }
    // dart:io reports a refused CONNECT as "Proxy failed to establish
    // tunnel (407 ...)".
    if (e is HttpException && e.message.contains('407')) {
      return const ProxyTestAuthRejected();
    }
    if (e is HandshakeException || e is TlsException) {
      return const ProxyTestTlsFailure();
    }
    if (e is SocketException) {
      if (e.message.contains('timed out')) return const ProxyTestTimeout();
      // Through an HTTP proxy every TCP connection the client opens goes to
      // the proxy (it reaches the target itself), so a socket error is the
      // proxy's. The exception cannot say so itself: its port is the local
      // ephemeral port, not the proxy's.
      if (proxy.kind == ProxyKind.http && _shouldProxy(_probe, proxy)) {
        return ProxyTestUnreachable(proxy.endpoint);
      }
      return ProxyTestFailed(
        redactProxyCredentials(e.osError?.message ?? e.message),
      );
    }
    return ProxyTestFailed(redactProxyCredentials('$e'));
  }
}
