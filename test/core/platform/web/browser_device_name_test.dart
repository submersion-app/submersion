import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/web/browser_device_name.dart';

/// The name a browser peer shows on every other device (issue #4121):
/// `<Browser> on <OS>` read off the user agent, since a page has neither a
/// hostname nor a native identity.
void main() {
  const cases = <String, String>{
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36':
        'Chrome on Windows',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0':
        'Edge on Windows',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 '
            'Firefox/130.0':
        'Firefox on Windows',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6_1) AppleWebKit/605.1.15 '
            '(KHTML, like Gecko) Version/17.6 Safari/605.1.15':
        'Safari on macOS',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36':
        'Chrome on macOS',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0':
        'Edge on macOS',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14.6; rv:130.0) Gecko/20100101 '
            'Firefox/130.0':
        'Firefox on macOS',
    'Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0':
        'Firefox on Linux',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/129.0.0.0 Safari/537.36':
        'Chrome on Linux',
    'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36':
        'Chrome on ChromeOS',
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36':
        'Chrome on Android',
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36 '
            'EdgA/129.0.0.0':
        'Edge on Android',
    'Mozilla/5.0 (Android 14; Mobile; rv:130.0) Gecko/130.0 Firefox/130.0':
        'Firefox on Android',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 '
            'Mobile/15E148 Safari/604.1':
        'Safari on iOS',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/129.0.0.0 '
            'Mobile/15E148 Safari/604.1':
        'Chrome on iOS',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/130.0 '
            'Mobile/15E148 Safari/605.1.15':
        'Firefox on iOS',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 '
            'EdgiOS/129.0.0.0 Mobile/15E148 Safari/604.1':
        'Edge on iOS',
  };

  cases.forEach((userAgent, expected) {
    test(expected, () => expect(browserDeviceName(userAgent), expected));
  });

  test('nothing recognised is just Browser', () {
    expect(browserDeviceName('curl/8.4.0'), 'Browser');
    expect(browserDeviceName(''), 'Browser');
  });

  test('a browser without a platform stands alone', () {
    expect(browserDeviceName('Chrome/129.0 Safari/537.36'), 'Chrome');
  });

  test('a platform without a known browser is Browser on it', () {
    expect(
      browserDeviceName('Mozilla/5.0 (Windows NT 10.0) Opera/12.0'),
      'Browser on Windows',
    );
  });
}
