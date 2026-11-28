// Moved from the equipment attribute catalogue (issue #5073) so dive
// sites can share it.

/// Turns a stored `url`-kind value into a launchable link, or null when it
/// is not one.
///
/// Two jobs, and the second is the important one:
/// 1. A bare host gets `https://` prepended. Retailers are written down as
///    "scubashop.com", not with a scheme, and refusing those would make the
///    field feel broken.
/// 2. Only `http` and `https` survive. The stored text is handed to
///    url_launcher, so a `file:`, `mailto:` or `javascript:` value would be
///    an arbitrary launch performed on the diver's behalf -- and the value
///    can arrive from a synced device or an import, not just from typing.
Uri? parseWebLink(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;

  // Deciding whether a leading "word:" is a scheme or a host with a port.
  // RFC 3986 allows dots in a scheme, so "shop.example.com:8080/item" parses
  // as scheme "shop.example.com" -- which would then be rejected below as a
  // non-web scheme, even though every browser reads it as host:port.
  //
  // The discriminator is the dot: real schemes ("mailto", "javascript",
  // "file", "ftp") do not contain one, hostnames always do. Anything with a
  // dotted prefix is treated as a host and gets https:// prepended.
  //
  // Deliberately NOT "prepend https:// unless it already starts with http(s)":
  // that turns "mailto:shop@example.com" into
  // "https://mailto:shop@example.com", which parses as userInfo "mailto:shop"
  // on host "example.com" -- a launchable website conjured out of a mailto,
  // exactly the substitution this function exists to prevent.
  final schemeMatch = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):').firstMatch(text);
  final hasScheme = schemeMatch != null && !schemeMatch.group(1)!.contains('.');
  final candidate = hasScheme ? text : 'https://$text';

  final uri = Uri.tryParse(candidate);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  // A host with no dot is a typo or a local name, not a retailer's site.
  if (!uri.host.contains('.')) return null;
  // No userInfo. "shop.example.com@evil.com" parses with host evil.com while
  // the detail row still shows the text as stored, so what the diver reads
  // and what the tap opens disagree -- the classic phishing shape. Nothing
  // legitimate about a product listing needs credentials in the URL, and a
  // url attribute can arrive from a synced device or an import rather than
  // from this diver's keyboard.
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}
