/// A page origin in the one form every origin comparison uses: trimmed,
/// lowercased, without trailing slashes.
///
/// Shared by the Google client check
/// (`GoogleDriveClientConfig.builtInWebClientIdFor`) and the hosted-site
/// check (`hostedWebSiteFor`, issue #4481), so a page that one treats as
/// Submersion's own site the other does too.
String normalizeWebOrigin(String origin) {
  var normalized = origin.trim().toLowerCase();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}
