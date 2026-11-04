import 'package:http/http.dart' as http;

import 'package:submersion/core/platform/web/cors_rule_templates.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';

/// Why a browser's connection test failed (issue #4121).
///
/// A browser hides the status of a request another origin refused and
/// reports a bare network failure, so the shape of the failure is read
/// instead of a status code.
enum CorsVerdict {
  /// Opaque on the first request: the store's CORS rules do not allow this
  /// site.
  blockedByCors,

  /// Opaque after a plain request got through: the method is not allowed
  /// (a WebDAV server that serves GET but not PROPFIND).
  methodBlockedByCors,

  /// Opaque only on a write: GET is allowed, PUT or DELETE is not.
  writeBlockedByCors,

  /// The store answered and refused the credentials.
  forbidden,

  /// No bucket, folder or sync data at the address.
  notFound,

  /// Opaque to a private HTTPS host: the browser does not trust the
  /// certificate, or cannot reach the host at all.
  tlsOrUnreachable,

  /// The check passed.
  ok,

  /// None of the above; the usual rule is still the first thing to try.
  unknown,
}

/// The kind of store, which decides which rule template to show.
enum StoreKind {
  awsS3,
  cloudflareR2,
  backblazeB2,
  minio,
  genericS3,
  nextcloud,
  genericWebDav,
}

/// A verdict with the store it was reached for and the site's origin, which
/// the rule template names.
class CorsDiagnosis {
  const CorsDiagnosis({
    required this.verdict,
    required this.kind,
    required this.origin,
    this.writes = true,
  });

  final CorsVerdict verdict;
  final StoreKind kind;
  final String origin;

  /// Whether the rule must allow writes too; sync always writes.
  final bool writes;

  /// Whether the verdict is one a CORS rule fixes.
  bool get needsRule => switch (verdict) {
    CorsVerdict.blockedByCors ||
    CorsVerdict.methodBlockedByCors ||
    CorsVerdict.writeBlockedByCors ||
    CorsVerdict.unknown => true,
    CorsVerdict.forbidden ||
    CorsVerdict.notFound ||
    CorsVerdict.tlsOrUnreachable ||
    CorsVerdict.ok => false,
  };

  /// The rule to add to the store, with [origin] filled in.
  String get ruleTemplate =>
      corsRuleTemplate(kind, origin: origin, writes: writes);
}

/// The kind of store at [endpoint]: the hosted S3 services by their
/// domains, MinIO by its name or default port, Nextcloud by its DAV path,
/// anything else generic.
StoreKind detectStoreKind(Uri endpoint, {required bool isWebDav}) {
  final host = endpoint.host.toLowerCase();
  if (isWebDav) {
    return endpoint.path.contains('/remote.php/dav')
        ? StoreKind.nextcloud
        : StoreKind.genericWebDav;
  }
  if (host.endsWith('amazonaws.com')) return StoreKind.awsS3;
  if (host.endsWith('r2.cloudflarestorage.com')) return StoreKind.cloudflareR2;
  if (host.endsWith('backblazeb2.com')) return StoreKind.backblazeB2;
  if (host.contains('minio') || endpoint.port == 9000) return StoreKind.minio;
  return StoreKind.genericS3;
}

/// Whether [error] is the bare network failure a browser reports for a
/// request another origin refused, looking through the causes the storage
/// clients wrap it in.
bool isOpaqueBrowserFailure(Object error) {
  Object? current = error;
  for (var depth = 0; current != null && depth < 6; depth++) {
    if (current is http.ClientException) {
      final message = current.message;
      if (message.contains('XMLHttpRequest error') ||
          message.contains('Failed to fetch') ||
          message.contains('NetworkError') ||
          message.contains('Load failed')) {
        return true;
      }
    }
    current = current is CloudStorageException ? current.cause : null;
  }
  return false;
}

/// Whether [host] is one the public internet does not route: a browser
/// reaching it over HTTPS failed on trust or reachability, not on CORS.
bool isPrivateHost(String host) {
  final h = host.toLowerCase();
  if (h.isEmpty || h == 'localhost' || h == '::1') return true;
  // IPv6: unique local (fc00::/7) and link local (fe80::/10).
  if (h.contains(':')) return RegExp(r'^(f[cd]|fe[89ab])').hasMatch(h);
  if (!h.contains('.')) return true;
  for (final suffix in [
    '.local',
    '.lan',
    '.home',
    '.home.arpa',
    '.internal',
    '.localdomain',
  ]) {
    if (h.endsWith(suffix)) return true;
  }
  final v4 = RegExp(r'^(\d+)\.(\d+)\.(\d+)\.(\d+)$').firstMatch(h);
  if (v4 != null) {
    final a = int.parse(v4.group(1)!);
    final b = int.parse(v4.group(2)!);
    return a == 10 ||
        a == 127 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 169 && b == 254);
  }
  return false;
}

/// Classifies a failed connection test from a browser.
CorsDiagnosis diagnose({
  required Object error,
  required Uri endpoint,
  required String origin,
  required bool isWebDav,
  required bool failedOnWrite,
  bool optionsSucceeded = false,
}) {
  final kind = detectStoreKind(endpoint, isWebDav: isWebDav);
  CorsDiagnosis of(CorsVerdict verdict) =>
      CorsDiagnosis(verdict: verdict, kind: kind, origin: origin);
  if (isOpaqueBrowserFailure(error)) {
    if (failedOnWrite) return of(CorsVerdict.writeBlockedByCors);
    if (optionsSucceeded) return of(CorsVerdict.methodBlockedByCors);
    if (endpoint.scheme == 'https' && isPrivateHost(endpoint.host)) {
      return of(CorsVerdict.tlsOrUnreachable);
    }
    return of(CorsVerdict.blockedByCors);
  }
  if (error is CloudStorageException && error.accessRefused) {
    return of(CorsVerdict.forbidden);
  }
  if (error is WebDavException && error.code == WebDavErrorCode.notFound) {
    return of(CorsVerdict.notFound);
  }
  final text = error.toString();
  if (text.contains('NoSuchBucket') || RegExp(r'\b404\b').hasMatch(text)) {
    return of(CorsVerdict.notFound);
  }
  if (RegExp(r'\b403\b').hasMatch(text) ||
      text.contains('AccessDenied') ||
      text.contains('Access denied')) {
    return of(CorsVerdict.forbidden);
  }
  return of(CorsVerdict.unknown);
}
