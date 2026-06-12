/// Static region derivation from an S3-compatible endpoint.
///
/// Pure function, no I/O. Providers that encode the region in the endpoint
/// hostname (or fix it to a constant) are matched here; everything else
/// falls back to `us-east-1`, which MinIO and region-agnostic servers
/// accept. A wrong guess is healed at request time by S3ApiClient's
/// server-assisted region correction.
String deriveRegion(String endpoint) {
  final trimmed = endpoint.trim();
  if (trimmed.isEmpty) return 'us-east-1';
  final host = Uri.tryParse(trimmed)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return 'us-east-1';
  if (host.endsWith('.r2.cloudflarestorage.com')) return 'auto';
  for (final pattern in _regionHostPatterns) {
    final match = pattern.firstMatch(host);
    if (match != null) return match.group(1)!;
  }
  return 'us-east-1';
}

/// Hostname shapes whose first capture group is the region. The AWS
/// pattern covers regional (`s3.{r}.`), dualstack (`s3.dualstack.{r}.`),
/// and legacy dash (`s3-{r}.`) hosts; the bare global endpoint
/// `s3.amazonaws.com` intentionally matches none of them.
final List<RegExp> _regionHostPatterns = [
  RegExp(r'(?:^|\.)s3[.-](?:dualstack\.)?([a-z0-9-]+)\.amazonaws\.com$'),
  RegExp(r'^s3\.([a-z0-9-]+)\.backblazeb2\.com$'),
  RegExp(r'(?:^|\.)([a-z0-9-]+)\.digitaloceanspaces\.com$'),
  RegExp(r'^s3\.([a-z0-9-]+)\.wasabisys\.com$'),
  RegExp(r'^s3\.([a-z0-9-]+)\.scw\.cloud$'),
];
