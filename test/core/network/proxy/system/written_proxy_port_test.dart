import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/system/written_proxy_port.dart';

void main() {
  test('no port written', () {
    for (final v in ['proxy', 'http://proxy/', '[::1]', 'u:p@proxy']) {
      expect(writtenProxyPort(v), (written: false, port: null), reason: v);
    }
  });

  test('a usable port, including the scheme default Uri would hide', () {
    expect(writtenProxyPort('proxy:8080'), (written: true, port: 8080));
    expect(writtenProxyPort('http://p:80/'), (written: true, port: 80));
    expect(writtenProxyPort('[::1]:3128'), (written: true, port: 3128));
    expect(writtenProxyPort('socks5://u:p@h:1080'), (
      written: true,
      port: 1080,
    ));
  });

  test('a written port outside 1 to 65535 is unusable', () {
    for (final v in ['proxy:0', 'x://proxy:65536', 'proxy:', '[::1]:0']) {
      expect(writtenProxyPort(v), (written: true, port: null), reason: v);
    }
  });
}
