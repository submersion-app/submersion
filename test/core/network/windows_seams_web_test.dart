import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system/windows_system_proxy_resolver_web.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/core/network/windows_root_store_web.dart';

/// The browser variants of the two Windows FFI seams, imported directly so
/// the VM can exercise what `flutter build web` links.
void main() {
  test('web root store reads no certificates', () {
    expect(readWindowsRootCertificates(), isEmpty);
  });

  test('web Windows proxy resolver goes direct', () async {
    final result = await WindowsSystemProxyResolver().resolve(
      Uri.parse('https://example.com/'),
    );
    expect(result, const SystemProxyNone());
  });

  test('web WinHTTP entry points are unsupported', () {
    expect(readIeProxyConfig, throwsUnsupportedError);
    expect(
      () => queryPacForUrl(
        'https://example.com/',
        const RawWindowsProxy(autoDetect: false),
      ),
      throwsUnsupportedError,
    );
  });
}
