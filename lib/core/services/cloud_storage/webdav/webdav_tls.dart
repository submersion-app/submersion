import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/services/cloud_storage/http_timeouts.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';

/// What the trust dialog shows about a rejected certificate.
class WebDavCertificateDetails {
  const WebDavCertificateDetails({
    required this.host,
    required this.port,
    required this.sha256,
    required this.subject,
    required this.issuer,
    required this.startValidity,
    required this.endValidity,
  });

  factory WebDavCertificateDetails.fromCertificate(
    X509Certificate cert,
    String host,
    int port,
  ) => WebDavCertificateDetails(
    host: host,
    port: port,
    sha256: certificateSha256Hex(cert.der),
    subject: cert.subject,
    issuer: cert.issuer,
    startValidity: cert.startValidity,
    endValidity: cert.endValidity,
  );

  final String host;
  final int port;

  /// Lowercase hex SHA-256 of the DER encoding.
  final String sha256;
  final String subject;
  final String issuer;
  final DateTime startValidity;
  final DateTime endValidity;

  String get formattedFingerprint => formatFingerprint(sha256);
}

String certificateSha256Hex(List<int> der) => sha256.convert(der).toString();

/// `0a1bff` as `0A:1B:FF`.
String formatFingerprint(String hex) {
  final upper = hex.toUpperCase();
  return [
    for (var i = 0; i + 1 < upper.length; i += 2) upper.substring(i, i + 2),
  ].join(':');
}

/// Whether a certificate that failed normal verification is the one the
/// user trusted, on the server the user configured.
bool pinAccepts({
  required String? pinnedSha256,
  required WebDavCertificateDetails presented,
  required String expectedHost,
  required int expectedPort,
}) =>
    pinnedSha256 != null &&
    pinnedSha256.toLowerCase() == presented.sha256.toLowerCase() &&
    presented.host.toLowerCase() == expectedHost.toLowerCase() &&
    presented.port == expectedPort;

/// The `badCertificateCallback` for one client. Dart calls it only for a
/// certificate that failed normal verification, so a CA-valid certificate
/// never reaches it and a stale pin is harmless. A rejection is recorded so
/// the client can turn the resulting handshake failure into a
/// [WebDavUntrustedCertificateException] the trust dialog can show.
class CertificateTrustRecorder {
  CertificateTrustRecorder({
    required this.expectedHost,
    required this.expectedPort,
    this.pinnedSha256,
  });

  factory CertificateTrustRecorder.forConfig(WebDavConfig config) =>
      CertificateTrustRecorder(
        expectedHost: config.host,
        expectedPort: config.port,
        pinnedSha256: config.pinnedCertSha256,
      );

  final String expectedHost;
  final int expectedPort;
  final String? pinnedSha256;

  WebDavCertificateDetails? _rejected;

  /// True to accept [presented]; false records it as the last rejection.
  bool evaluate(WebDavCertificateDetails presented) {
    if (pinAccepts(
      pinnedSha256: pinnedSha256,
      presented: presented,
      expectedHost: expectedHost,
      expectedPort: expectedPort,
    )) {
      return true;
    }
    _rejected = presented;
    return false;
  }

  bool onBadCertificate(X509Certificate cert, String host, int port) =>
      evaluate(WebDavCertificateDetails.fromCertificate(cert, host, port));

  /// The last rejected certificate, cleared on read.
  WebDavCertificateDetails? takeRejected() {
    final rejected = _rejected;
    _rejected = null;
    return rejected;
  }
}

/// A transport whose TCP connect is bounded and whose TLS layer consults
/// [recorder]. Built with `HttpClient()`, so `AppHttpOverrides` (the
/// Windows root store) still applies. Response and idle deadlines are the
/// WebDavClient's: a WebDAV upload is one request for the whole file, so the
/// shared TimeoutHttpClient's fixed ten-minute upload cap would fail every
/// large upload on a slow link.
http.Client createWebDavHttpClient(CertificateTrustRecorder recorder) {
  final inner = HttpClient()
    ..connectionTimeout = TimeoutHttpClient.defaultConnectTimeout;
  // Through AppHttpOverrides, not the client's own setter: the app's proxy
  // support opens direct and SOCKS5 TLS sockets itself, where dart:io never
  // consults HttpClient.badCertificateCallback.
  AppHttpOverrides.setBadCertificateCallback(inner, recorder.onBadCertificate);
  return IOClient(inner);
}
