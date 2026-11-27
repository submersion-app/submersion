import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/hosted_web_site.dart';

/// Issue #4481: Submersion serves the web app at two addresses, the stable
/// site and the beta site, and the app tells them apart by the page's own
/// origin, since promotion re-hosts the beta's files unchanged.
void main() {
  group('hostedWebSiteFor', () {
    test('recognises each site by its exact origin', () {
      expect(
        hostedWebSiteFor('https://web.submersion.app'),
        HostedWebSite.stable,
      );
      expect(
        hostedWebSiteFor('https://beta.web.submersion.app'),
        HostedWebSite.beta,
      );
    });

    test('ignores case and a trailing slash', () {
      expect(
        hostedWebSiteFor('HTTPS://Beta.Web.Submersion.App/'),
        HostedWebSite.beta,
      );
      expect(
        hostedWebSiteFor(' https://web.submersion.app// '),
        HostedWebSite.stable,
      );
    });

    test('anything else is none', () {
      const others = [
        // Plain http, a port and a look-alike host are other origins: the
        // browser keeps a separate library for each.
        'http://web.submersion.app',
        'https://web.submersion.app:8443',
        'https://evil.web.submersion.app',
        'https://submersion.app',
        // A local dev server and a self-hosted copy.
        'http://localhost:8080',
        'https://dives.example.org',
        '',
      ];
      for (final origin in others) {
        expect(hostedWebSiteFor(origin), HostedWebSite.none, reason: origin);
      }
    });
  });

  group('HostedWebSiteLinks', () {
    test("links build each site's address", () {
      expect(HostedWebSite.stable.uri.toString(), 'https://web.submersion.app');
      expect(
        HostedWebSite.beta.uri.toString(),
        'https://beta.web.submersion.app',
      );
      expect(HostedWebSite.none.uri, isNull);
    });

    test('each site points at the other one', () {
      expect(HostedWebSite.stable.other, HostedWebSite.beta);
      expect(HostedWebSite.beta.other, HostedWebSite.stable);
      expect(HostedWebSite.none.other, isNull);
    });
  });

  test('a native build is never a hosted site', () {
    // The VM's Uri.base is a file: URI, whose origin throws; reading it
    // would crash every native build that opens About.
    expect(currentHostedWebSite, HostedWebSite.none);
  });
}
