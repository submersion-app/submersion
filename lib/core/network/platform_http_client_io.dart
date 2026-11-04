import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'package:submersion/core/network/proxy/app_http_overrides.dart';

/// A client over `dart:io`'s HttpClient.
///
/// [connectionTimeout] bounds the TCP connect: a bare `http.Client()` leaves
/// it null, so a connect to an unreachable endpoint waits on the OS default,
/// minutes on some Windows configurations. Null keeps that default for the
/// one caller that wants it.
///
/// [omitDefaultUserAgent] drops dart:io's own `User-Agent`, so the header a
/// request sets is the one that reaches the server (map tile servers require
/// an identifying agent).
///
/// [onBadCertificate] is installed through [AppHttpOverrides], not the
/// client's own setter: the app's proxy support opens direct and SOCKS5 TLS
/// sockets itself, where dart:io never consults `badCertificateCallback`.
http.Client createPlatformHttpClient({
  Duration? connectionTimeout = const Duration(seconds: 15),
  bool omitDefaultUserAgent = false,
  BadCertificateCallback? onBadCertificate,
}) {
  final inner = HttpClient()..connectionTimeout = connectionTimeout;
  if (omitDefaultUserAgent) inner.userAgent = null;
  if (onBadCertificate != null) {
    AppHttpOverrides.setBadCertificateCallback(inner, onBadCertificate);
  }
  return IOClient(inner);
}
