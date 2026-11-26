import 'package:submersion/features/media/data/synology/synology_share_link.dart';

/// The form two manifest URLs are compared in, so pasting the same feed a
/// second time finds the subscription that already reads it.
///
/// A Synology Photos share link reduces to its origin and share code: the
/// web client adds a trailing slash or a `/photo` prefix depending on where
/// the link was copied from, and both reach the same album. Any other URL
/// is compared as typed, minus surrounding whitespace, because a feed's
/// query string can select a different feed.
String canonicalManifestUrl(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;
  final share = SynologyShareLink.tryParseShareLink(uri);
  if (share != null) {
    return '${share.origin}/mo/sharing/${share.code}';
  }
  return trimmed;
}
