/// The port written in a proxy value such as `host:8080`, `[::1]:3128` or
/// `http://user:pw@host:3128/`.
///
/// `written` is false when the value names no port. `port` is null when one
/// is written but is not 1 to 65535: such a value is unusable, and the
/// caller moves on to its next candidate. Read from the text because Uri
/// reports an explicit port equal to the scheme's default (0 for an unknown
/// scheme) as no port at all.
({bool written, int? port}) writtenProxyPort(String value) {
  var rest = value.trim();
  final scheme = rest.indexOf('://');
  if (scheme >= 0) rest = rest.substring(scheme + 3);
  final slash = rest.indexOf('/');
  if (slash >= 0) rest = rest.substring(0, slash);
  final at = rest.lastIndexOf('@');
  if (at >= 0) rest = rest.substring(at + 1);
  final match = RegExp(r'^(?:\[[^\]]*\]|[^:\[\]]*):(\d*)$').firstMatch(rest);
  if (match == null) return (written: false, port: null);
  final port = int.tryParse(match.group(1)!);
  final usable = port != null && port >= 1 && port <= 65535;
  return (written: true, port: usable ? port : null);
}
