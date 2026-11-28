import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/web_origin.dart';

/// One normaliser for every comparison of a page's origin, so the Google
/// client check and the hosted-site check (issue #4481) always agree.
void main() {
  test('lowercases, trims and drops trailing slashes', () {
    expect(
      normalizeWebOrigin(' HTTPS://Beta.Web.Submersion.App// '),
      'https://beta.web.submersion.app',
    );
    expect(
      normalizeWebOrigin('https://web.submersion.app'),
      'https://web.submersion.app',
    );
  });

  test('keeps what makes an origin distinct', () {
    expect(
      normalizeWebOrigin('http://localhost:8080/'),
      'http://localhost:8080',
    );
    expect(normalizeWebOrigin(''), '');
    expect(normalizeWebOrigin('///'), '');
  });
}
