import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/startup_gated_http_client.dart';

/// Records every member the wrapper reaches, with its arguments.
class _Recording implements HttpClient {
  final calls = <Invocation>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return null;
  }
}

void main() {
  test('passes every client setting and credential straight through', () {
    final inner = _Recording();
    final client = StartupGatedHttpClient(inner, () => null);
    final url = Uri.parse('https://example.test/');
    final credentials = HttpClientBasicCredentials('ann', 'pw');
    Future<bool> authenticate(Uri u, String s, String? r) async => true;
    Future<bool> authenticateProxy(
      String h,
      int p,
      String s,
      String? r,
    ) async => true;
    Future<ConnectionTask<Socket>> factory(Uri u, String? h, int? p) =>
        Socket.startConnect('127.0.0.1', 1);
    String findProxy(Uri u) => 'DIRECT';
    bool badCertificate(X509Certificate c, String h, int p) => false;
    void keyLog(String line) {}

    client
      ..authenticate = authenticate
      ..addCredentials(url, 'realm', credentials)
      ..connectionFactory = factory
      ..findProxy = findProxy
      ..authenticateProxy = authenticateProxy
      ..addProxyCredentials('proxy', 3128, 'realm', credentials)
      ..badCertificateCallback = badCertificate
      ..keyLog = keyLog
      ..close(force: true);

    expect(inner.calls.map((c) => c.memberName), [
      const Symbol('authenticate='),
      #addCredentials,
      const Symbol('connectionFactory='),
      const Symbol('findProxy='),
      const Symbol('authenticateProxy='),
      #addProxyCredentials,
      const Symbol('badCertificateCallback='),
      const Symbol('keyLog='),
      #close,
    ]);
    expect(inner.calls[0].positionalArguments.single, authenticate);
    expect(inner.calls[1].positionalArguments, [url, 'realm', credentials]);
    expect(inner.calls[2].positionalArguments.single, factory);
    expect(inner.calls[3].positionalArguments.single, findProxy);
    expect(inner.calls[4].positionalArguments.single, authenticateProxy);
    expect(inner.calls[5].positionalArguments, [
      'proxy',
      3128,
      'realm',
      credentials,
    ]);
    expect(inner.calls[6].positionalArguments.single, badCertificate);
    expect(inner.calls[7].positionalArguments.single, keyLog);
    expect(inner.calls[8].namedArguments, {#force: true});
  });
}
