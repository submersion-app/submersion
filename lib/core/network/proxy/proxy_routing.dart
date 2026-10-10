import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/network/proxy/effective_proxy.dart';

/// Decides whether one request goes through the snapshot's proxy.
typedef ProxyRoutingPolicy = bool Function(Uri url, EffectiveProxy proxy);

/// The production policy: proxy unless the snapshot is direct, the host is
/// this machine or the LAN, or the OS bypass list names it.
bool defaultShouldProxy(Uri url, EffectiveProxy proxy) {
  if (proxy.isDirect) return false;
  final host = url.host;
  if (isAlwaysDirectHost(host)) return false;
  return !matchesBypass(host, proxy.bypass);
}

String _normalize(String host) {
  var h = host.trim().toLowerCase();
  if (h.endsWith('.')) h = h.substring(0, h.length - 1);
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  return h;
}

final _privateRanges = [
  for (final range in const [
    '127.0.0.0/8',
    '10.0.0.0/8',
    '172.16.0.0/12',
    '192.168.0.0/16',
    '169.254.0.0/16',
    '::1/128',
    'fc00::/7',
    'fe80::/10',
  ])
    _Cidr.parse(range)!,
];

/// This machine and the local network: never proxied in any mode, so LAN
/// features (the media network scan, a NAS) keep working.
bool isAlwaysDirectHost(String host) {
  final h = _normalize(host);
  if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local')) {
    return true;
  }
  final address = InternetAddress.tryParse(h);
  if (address == null) return false;
  return _privateRanges.any((r) => r.contains(address));
}

/// Whether [host] matches an OS bypass entry: an exact host (which also
/// covers its subdomains, as curl's no_proxy does), `*.domain`, `.domain`,
/// `*`, a CIDR range (macOS's short `203.0.113/24` included), or Windows'
/// `<local>` for single-label names.
bool matchesBypass(String host, List<String> bypass) {
  final h = _normalize(host);
  final address = InternetAddress.tryParse(h);
  // A snapshot's bypass list is checked on every request; its CIDR entries
  // are parsed once per list rather than per request.
  final cidrs = _cidrCache[bypass] ??= {
    for (final raw in bypass)
      if (raw.contains('/')) raw: _Cidr.parse(raw.trim().toLowerCase()),
  };
  for (final raw in bypass) {
    var entry = raw.trim().toLowerCase();
    if (entry.isEmpty) continue;
    if (entry == '*') return true;
    if (entry == '<local>') {
      if (address == null && !h.contains('.')) return true;
      continue;
    }
    if (entry.contains('/')) {
      final cidr = cidrs[raw];
      if (cidr != null && address != null && cidr.contains(address)) {
        return true;
      }
      continue;
    }
    // Drop a port: the bypass decision is per host here. An entry with one
    // colon is host:port; more colons make it an IPv6 address.
    final colon = entry.lastIndexOf(':');
    if (colon > 0 && entry.indexOf(':') == colon) {
      entry = entry.substring(0, colon);
    }
    if (entry.startsWith('*.')) entry = entry.substring(1);
    if (entry.startsWith('.')) {
      if (h == entry.substring(1) || h.endsWith(entry)) return true;
      continue;
    }
    if (h == entry || h.endsWith('.$entry')) return true;
  }
  return false;
}

final _cidrCache = Expando<Map<String, _Cidr?>>('proxy bypass CIDRs');

/// An address range in CIDR notation.
class _Cidr {
  _Cidr(this._network, this._prefix);

  final Uint8List _network;
  final int _prefix;

  static _Cidr? parse(String text) {
    final slash = text.indexOf('/');
    if (slash <= 0) return null;
    var addressText = text.substring(0, slash);
    final prefix = int.tryParse(text.substring(slash + 1));
    if (prefix == null || prefix < 0) return null;
    if (!addressText.contains(':')) {
      // macOS writes `203.0.113/24`; pad the missing octets with zeros.
      final parts = addressText.split('.');
      if (parts.length > 4) return null;
      addressText = [...parts, ...List.filled(4 - parts.length, '0')].join('.');
    }
    final address = InternetAddress.tryParse(addressText);
    if (address == null) return null;
    if (prefix > address.rawAddress.length * 8) return null;
    return _Cidr(address.rawAddress, prefix);
  }

  bool contains(InternetAddress address) {
    final bytes = address.rawAddress;
    if (bytes.length != _network.length) return false;
    var bits = _prefix;
    for (var i = 0; i < bytes.length && bits > 0; i++) {
      final take = bits >= 8 ? 8 : bits;
      final mask = (0xff << (8 - take)) & 0xff;
      if ((bytes[i] & mask) != (_network[i] & mask)) return false;
      bits -= take;
    }
    return true;
  }
}
