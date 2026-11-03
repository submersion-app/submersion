import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/browser_host_platform.dart';

/// The browser composition behind `host_platform_web.dart`, fed a fake
/// `navigator` so it runs on the VM.
void main() {
  const info = BrowserInfo(
    userAgent: 'Mozilla/5.0 (Macintosh) Chrome/142.0',
    language: 'en-GB',
    hardwareConcurrency: 8,
  );
  const browser = BrowserHostPlatform(info);

  test('is the web and no native platform', () {
    expect(browser.isWeb, isTrue);
    expect(browser.isAndroid, isFalse);
    expect(browser.isIOS, isFalse);
    expect(browser.isMacOS, isFalse);
    expect(browser.isWindows, isFalse);
    expect(browser.isLinux, isFalse);
    expect(browser.isApple, isFalse);
    expect(browser.isDesktop, isFalse);
    expect(browser.isMobile, isFalse);
  });

  test(
    'answers from navigator where it can and with blanks where it cannot',
    () {
      expect(browser.operatingSystem, 'web');
      expect(browser.operatingSystemVersion, info.userAgent);
      expect(browser.localeName, 'en-GB');
      expect(browser.numberOfProcessors, 8);
      expect(browser.pathSeparator, '/');
      expect(browser.environment, isEmpty);
      expect(browser.localHostname, isNull);
      expect(browser.resolvedExecutable, '');
    },
  );

  test('reports at least one processor when the browser reports none', () {
    const starved = BrowserHostPlatform(
      BrowserInfo(userAgent: 'x', language: 'en', hardwareConcurrency: 0),
    );
    expect(starved.numberOfProcessors, 1);
  });
}
