/// Short names for storage accounts and stores (issue #3522).
///
/// S3 rows and media store hints are labelled "bucket @ host", and some
/// services put account ids in the host (Cloudflare R2's is a 32-character
/// hex id). A well-known host reads as its service's name instead, so
/// "submersion-sync @ 149b...926.r2.cloudflarestorage.com" becomes
/// "submersion-sync @ Cloudflare R2". The stored label is never rewritten:
/// it stays the technical record the deduplicator and older builds read.
library;

/// Host domain suffixes of well-known S3 services and the name each reads
/// as. A host matches when it equals the domain or ends with "." plus it.
const List<(String, String)> _knownStorageHosts = [
  ('r2.cloudflarestorage.com', 'Cloudflare R2'),
  ('amazonaws.com', 'Amazon S3'),
  ('backblazeb2.com', 'Backblaze B2'),
  ('wasabisys.com', 'Wasabi'),
  ('digitaloceanspaces.com', 'DigitalOcean Spaces'),
  ('storage.googleapis.com', 'Google Cloud Storage'),
  ('linodeobjects.com', 'Akamai (Linode) Object Storage'),
  ('scw.cloud', 'Scaleway'),
];

/// "bucket @ host" with an optional trailing " (folder)" note, as written
/// by every S3 connect path and the shared-library account setup.
final RegExp _bucketAtHost = RegExp(r'^(.+) @ (\S+)( \(.*\))?$');

/// The service name for [host], or null when it is not a known service.
String? storageServiceName(String host) {
  final lower = host.toLowerCase();
  for (final (domain, name) in _knownStorageHosts) {
    if (lower == domain || lower.endsWith('.$domain')) return name;
  }
  return null;
}

/// [label] with a well-known service's host replaced by its name; any other
/// label (an own server, WebDAV, a provider name) comes back unchanged.
String shortStorageLabel(String label) {
  final match = _bucketAtHost.firstMatch(label);
  if (match == null) return label;
  final service = storageServiceName(match.group(2)!);
  if (service == null) return label;
  return '${match.group(1)} @ $service${match.group(3) ?? ''}';
}

/// The name a store or account is shown under: the account's [nickname]
/// when the diver chose one, else [label] shortened.
String accountDisplayName({required String label, String? nickname}) {
  final chosen = nickname?.trim();
  if (chosen != null && chosen.isNotEmpty) return chosen;
  return shortStorageLabel(label);
}
