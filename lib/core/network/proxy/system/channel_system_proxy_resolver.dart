import 'package:flutter/services.dart';

import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

/// macOS, iOS and Android: the native SystemProxyHandler answers over
/// `app.submersion/system_proxy`. Parsing lives here, where it is testable;
/// the handlers only report what the OS said.
class ChannelSystemProxyResolver implements SystemProxyResolver {
  ChannelSystemProxyResolver({
    MethodChannel channel = const MethodChannel('app.submersion/system_proxy'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('resolve', {
        'url': probe.toString(),
      });
      return parseChannelProxyResult(raw);
    } on MissingPluginException {
      // No handler on this platform (or a test host): nothing to follow.
      return const SystemProxyNone();
    } on PlatformException catch (e) {
      return SystemProxyUnavailable(
        SystemProxyUnavailableReason.platformError,
        detail: e.message ?? e.code,
      );
    }
  }
}

/// Parses the handler's answer: `{kind: none}`,
/// `{kind: fixed, type, host, port, bypass, viaPac}` or
/// `{kind: unavailable, reason, detail}`. Anything else is a platform error.
SystemProxyResult parseChannelProxyResult(Object? raw) {
  const malformed = SystemProxyUnavailable(
    SystemProxyUnavailableReason.platformError,
    detail: 'Unexpected answer from the system proxy handler',
  );
  if (raw is! Map) return malformed;
  switch (raw['kind']) {
    case 'none':
      return SystemProxyNone(viaPac: raw['viaPac'] == true);
    case 'fixed':
      final host = raw['host'];
      final port = raw['port'];
      if (host is! String || host.isEmpty) return malformed;
      if (port is! int || port < 1 || port > 65535) return malformed;
      final type = switch (raw['type']) {
        'http' => ProxyType.http,
        'socks5' => ProxyType.socks5,
        _ => null,
      };
      // An unknown protocol must not be guessed at: speaking HTTP to a
      // proxy of another kind fails every request.
      if (type == null) return malformed;
      final bypass = raw['bypass'];
      return SystemProxyFixed(
        type: type,
        host: host,
        port: port,
        bypass: bypass is List ? bypass.whereType<String>().toList() : const [],
        viaPac: raw['viaPac'] == true,
      );
    case 'unavailable':
      final reason = SystemProxyUnavailableReason.values
          .where((r) => r.name == raw['reason'])
          .firstOrNull;
      final detail = raw['detail'];
      return SystemProxyUnavailable(
        reason ?? SystemProxyUnavailableReason.platformError,
        detail: detail is String ? detail : null,
      );
    default:
      return malformed;
  }
}
