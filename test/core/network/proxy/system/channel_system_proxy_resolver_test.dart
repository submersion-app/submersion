import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/channel_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseChannelProxyResult', () {
    test(
      'none',
      () => expect(
        parseChannelProxyResult({'kind': 'none'}),
        const SystemProxyNone(),
      ),
    );
    test('a PAC script choosing direct is marked as such', () {
      expect(
        parseChannelProxyResult({'kind': 'none', 'viaPac': true}),
        const SystemProxyNone(viaPac: true),
      );
    });
    test('fixed with bypass and PAC flag', () {
      expect(
        parseChannelProxyResult({
          'kind': 'fixed',
          'type': 'socks5',
          'host': 'h',
          'port': 1080,
          'bypass': ['*.corp', 7],
          'viaPac': true,
        }),
        const SystemProxyFixed(
          type: ProxyType.socks5,
          host: 'h',
          port: 1080,
          bypass: ['*.corp'],
          viaPac: true,
        ),
      );
    });
    test('unavailable reason and detail', () {
      expect(
        parseChannelProxyResult({
          'kind': 'unavailable',
          'reason': 'pacFailed',
          'detail': 'timeout',
        }),
        const SystemProxyUnavailable(
          SystemProxyUnavailableReason.pacFailed,
          detail: 'timeout',
        ),
      );
    });
    test('malformed answers are platformError', () {
      for (final raw in <Object?>[
        null,
        'x',
        {'kind': 'fixed', 'host': 'h'},
        {'kind': 'fixed', 'host': '', 'port': 1},
        {'kind': 'fixed', 'host': 'h', 'port': 0},
        {'kind': '?'},
        {'kind': 'fixed', 'type': 'socks4', 'host': 'h', 'port': 1},
        {'kind': 'fixed', 'host': 'h', 'port': 1},
      ]) {
        expect(
          parseChannelProxyResult(raw),
          isA<SystemProxyUnavailable>().having(
            (u) => u.reason,
            'reason',
            SystemProxyUnavailableReason.platformError,
          ),
          reason: '$raw',
        );
      }
    });
  });

  test('resolve sends the probe url and maps a platform exception', () async {
    const channel = MethodChannel('app.submersion/system_proxy');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Object? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call.arguments;
      throw PlatformException(code: 'boom');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final r = await ChannelSystemProxyResolver().resolve(
      Uri.parse('https://api.github.com/'),
    );
    expect(seen, {'url': 'https://api.github.com/'});
    expect(
      r,
      isA<SystemProxyUnavailable>().having(
        (u) => u.reason,
        'reason',
        SystemProxyUnavailableReason.platformError,
      ),
    );
  });

  test('a missing handler is none, not an error', () async {
    final r = await ChannelSystemProxyResolver(
      channel: const MethodChannel('nobody.home'),
    ).resolve(Uri.parse('https://api.github.com/'));
    expect(r, const SystemProxyNone());
  });
}
