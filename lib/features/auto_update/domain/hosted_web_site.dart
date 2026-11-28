import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/utils/web_origin.dart';

/// Which of Submersion's own web sites this page is (issue #4481).
///
/// Submersion serves the browser app twice: stable releases at the stable
/// site and every beta at the beta site. Each is its own origin, so each
/// keeps its own library in the browser.
enum HostedWebSite { stable, beta, none }

/// The two sites' host names.
///
/// Host names, never `https://` addresses: `scripts/web/stage_hosted_site.py`
/// checks a bundle is authorised for its site by finding `https://<host>` in
/// the compiled app, which proves something only while the
/// `GOOGLE_WEB_CLIENT_ORIGINS` define is the one place that spells it.
/// `test/architecture/hosted_web_site_literals_test.dart` keeps it that way.
const kStableWebSiteHost = 'web.submersion.app';
const kBetaWebSiteHost = 'beta.web.submersion.app';

/// The site a page served from [pageOrigin] is, or [HostedWebSite.none] for
/// any other address: a self-hosted copy, a local dev server.
///
/// Read from the address because nothing fixed at build time can tell the
/// sites apart: promotion re-hosts the beta's files on the stable site
/// unchanged. Compared in [normalizeWebOrigin]'s form, the one the Google
/// client check (`GoogleDriveClientConfig.builtInWebClientIdFor`) uses.
HostedWebSite hostedWebSiteFor(String pageOrigin) {
  final origin = normalizeWebOrigin(pageOrigin);
  for (final site in const [HostedWebSite.stable, HostedWebSite.beta]) {
    if (origin == site.uri.toString()) return site;
  }
  return HostedWebSite.none;
}

/// The site this page is. Always [HostedWebSite.none] off the web, where
/// `Uri.base` is a `file:` URI whose origin throws.
HostedWebSite get currentHostedWebSite =>
    HostPlatform.isWeb ? hostedWebSiteFor(Uri.base.origin) : HostedWebSite.none;

extension HostedWebSiteLinks on HostedWebSite {
  /// The site's address, or null for [HostedWebSite.none].
  Uri? get uri => switch (this) {
    HostedWebSite.stable => Uri(scheme: 'https', host: kStableWebSiteHost),
    HostedWebSite.beta => Uri(scheme: 'https', host: kBetaWebSiteHost),
    HostedWebSite.none => null,
  };

  /// The site to offer from this one, or null for [HostedWebSite.none].
  HostedWebSite? get other => switch (this) {
    HostedWebSite.stable => HostedWebSite.beta,
    HostedWebSite.beta => HostedWebSite.stable,
    HostedWebSite.none => null,
  };
}
