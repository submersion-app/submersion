/// Masking for credentials in text bound for the persisted log file.
///
/// The log file is what users attach to public bug reports, and warnings and
/// errors reach it whether or not debug mode is on (#1826). Call sites are
/// audited not to log secrets, but an exception's `toString()` can still
/// carry a request URL, a header or a response body nobody chose to log.
/// This is the backstop: it recognises secrets by the field names and shapes
/// they travel in, because the values themselves (opaque tokens) have no
/// reliable shape of their own.
library;

/// Replacement text for a masked value.
const redactedPlaceholder = '[REDACTED]';

/// Separator between a field name and its value, covering query strings,
/// JSON (`"key": "value"`) and Dart `Map.toString` (`{key: value}`).
///
/// Horizontal whitespace only: exports redact many log lines joined
/// together, and `\s` would let a line ending in `token:` swallow the start
/// of the next entry.
const _separator = r'''(["']?[ \t]*[:=][ \t]*)''';

/// A quoted value, taken whole because it may contain spaces (a passphrase).
const _quoted =
    r'"[^"\n]*"'
    r"|'[^'\n]*'";

/// A value in a `key=value`, `key: value` or `"key": "value"` pair: a quoted
/// string, or a bare run up to whitespace, a quote, or the next field or
/// query separator.
const _value =
    '($_quoted|'
    r'''[^\s"'&,;}\])]+)''';

/// [redactedPlaceholder], keeping the quotes around a quoted [value] so the
/// surrounding JSON or map text still reads as it did.
String _mask(String value) => switch (value[0]) {
  '"' => '"$redactedPlaceholder"',
  "'" => "'$redactedPlaceholder'",
  _ => redactedPlaceholder,
};

final List<(RegExp, String Function(Match))> _rules = [
  // Whole header values that may contain spaces ("Basic dXNl..."), including
  // vendor variants such as Suunto's STTAuthorization. An Authorization
  // value ends at a comma (the next header in a printed map); a Cookie value
  // runs on, because it separates its own pairs with `;` and `,`.
  (
    RegExp(
      r'''(?<![\w-])([\w-]*authorization)'''
      '$_separator($_quoted|'
      r'''[^"'\n,;}]+)''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}${m[2]}${_mask(m[3]!)}',
  ),
  (
    RegExp(
      r'''(?<![\w-])((?:set-)?cookie)'''
      '$_separator($_quoted|'
      r'''[^"'\n}]+)''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}${m[2]}${_mask(m[3]!)}',
  ),
  // Named secret fields: OAuth tokens and client secrets, passwords, API and
  // session keys, S3 secret keys and signed-URL credentials and signatures.
  (
    RegExp(
      r'''(?<![\w-])('''
      r'''[\w-]*token|[\w-]*secret|[\w-]*password|passwd'''
      r'''|secret[\w-]*key|api[_-]?key|session[_-]?key'''
      r'''|x-(?:amz|goog)-(?:signature|credential)'''
      r''')'''
      '$_separator$_value',
      caseSensitive: false,
    ),
    (m) => '${m[1]}${m[2]}${_mask(m[3]!)}',
  ),
  // The request signature of an AWS SigV4 Authorization header, whose value
  // the header rule above stops masking at the first comma.
  (
    RegExp(r'(?<![\w-])(Signature=)[0-9a-fA-F]{64}\b'),
    (m) => '${m[1]}$redactedPlaceholder',
  ),
  // Query-string-only names, too generic to match in free text: OAuth codes,
  // signed-link signatures and keys (user-supplied media and manifest URLs
  // are logged when they fail), Drive upload sessions, SSO tickets.
  (
    RegExp(
      '([?&](?:code|code_verifier|signature|sig|key|rlkey|ticket|upload_id)=)'
      '$_value',
      caseSensitive: false,
    ),
    (m) => '${m[1]}$redactedPlaceholder',
  ),
  // The SQLCipher key: SqliteException.toString() echoes the failing
  // statement, and `PRAGMA key` / `ATTACH ... KEY` carry it as x'<hex>'.
  (RegExp(r"\b[xX]'[0-9a-fA-F]{16,}'"), (_) => "x'$redactedPlaceholder'"),
  (
    RegExp(
      r'''(PRAGMA[ \t]+(?:re)?key[ \t]*=[ \t]*)("[^"\n]*"|'[^'\n]*')''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}"$redactedPlaceholder"',
  ),
  // Token shapes that are recognisable without a field name: Google access
  // and refresh tokens and client secrets, Dropbox short-lived tokens, JWTs.
  (
    RegExp(
      r'\bya29\.[\w-]+'
      r'|(?<![\w/])1//[\w-]{20,}'
      r'|\bGOCSPX-[\w-]+'
      r'|\bsl\.[\w-]{20,}'
      r'|\beyJ[\w-]+\.[\w-]+\.[\w-]*',
    ),
    (_) => redactedPlaceholder,
  ),
  // A bare bearer token outside an Authorization header.
  (
    RegExp(r'\b(Bearer[ \t]+)[\w\-.~+/]{8,}=*', caseSensitive: false),
    (m) => '${m[1]}$redactedPlaceholder',
  ),
  // Credentials embedded in a URL: scheme://user:password@host.
  (
    RegExp(
      r'\b([a-z][a-z0-9+.-]*://)[^/\s:@]+:[^/\s@]+@',
      caseSensitive: false,
    ),
    (m) => '${m[1]}$redactedPlaceholder@',
  ),
  // AWS access key ids (long-term AKIA, temporary ASIA).
  (RegExp(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'), (_) => redactedPlaceholder),
];

/// Return [input] with every recognised secret replaced by
/// [redactedPlaceholder]. Text without secrets is returned unchanged.
String redactSecrets(String input) {
  var output = input;
  for (final (pattern, replace) in _rules) {
    output = output.replaceAllMapped(pattern, replace);
  }
  return output;
}
