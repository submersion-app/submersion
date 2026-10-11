import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';

/// Why a WebDAV operation failed. The settings UI localizes from this; the
/// English [CloudStorageException.message] is for the sync status line and
/// logs.
enum WebDavErrorCode {
  invalidConfig,
  unauthorized,
  forbidden,
  notFound,
  notWebDav,
  redirected,
  conflict,
  tooLarge,
  insufficientStorage,
  locked,
  unreachable,
  server,
  unexpected,
  untrustedCertificate,
}

class WebDavException extends CloudStorageException {
  WebDavException(
    String message, {
    required this.code,
    this.statusCode,
    this.location,
    this.sizeBytes,
    this.host,
    Object? cause,
  }) : super(message, cause);

  final WebDavErrorCode code;
  final int? statusCode;

  /// The redirect target, for [WebDavErrorCode.redirected].
  final String? location;

  /// The refused upload's size, for [WebDavErrorCode.tooLarge].
  final int? sizeBytes;

  /// The server that could not be reached, for [WebDavErrorCode.unreachable].
  final String? host;

  static const int _excerptLimit = 300;

  /// Maps a non-success reply. [isRoot] marks a request for the DAV root
  /// itself, whose 404 means the address is wrong rather than a file being
  /// absent. The cause carries method, path and a bounded body excerpt;
  /// URIs never hold credentials (auth is a header), so it is safe to show.
  factory WebDavException.fromStatus(
    int status, {
    required String method,
    required Uri uri,
    String? location,
    String? bodyExcerpt,
    int? sizeBytes,
    bool isRoot = false,
  }) {
    final excerpt = (bodyExcerpt ?? '').trim();
    final bounded = excerpt.length <= _excerptLimit
        ? excerpt
        : '${excerpt.substring(0, _excerptLimit)}...';
    final cause =
        'HTTP $status $method ${uri.path}'
        '${bounded.isEmpty ? '' : ': $bounded'}';
    final (code, message) = switch (status) {
      401 => (
        WebDavErrorCode.unauthorized,
        'The server rejected the username or password. If the account uses '
            'two-factor sign-in, create an app password.',
      ),
      403 => (
        WebDavErrorCode.forbidden,
        'No permission for this folder on the WebDAV server.',
      ),
      405 when method == 'PROPFIND' => (
        WebDavErrorCode.notWebDav,
        'This address is not a WebDAV endpoint.',
      ),
      404 when isRoot => (
        WebDavErrorCode.notFound,
        'No WebDAV folder at this address. Check the server type and URL.',
      ),
      404 => (WebDavErrorCode.notFound, 'Not found on the WebDAV server.'),
      >= 300 && < 400 => (
        WebDavErrorCode.redirected,
        'The server redirected to ${location ?? 'another address'}. Use that address instead.',
      ),
      409 => (
        WebDavErrorCode.conflict,
        'The parent folder does not exist on the WebDAV server.',
      ),
      413 => (
        WebDavErrorCode.tooLarge,
        'The server refused a file of ${_megabytes(sizeBytes)} MB as too large. '
            'Raise its upload limit.',
      ),
      423 => (
        WebDavErrorCode.locked,
        'The file is locked on the WebDAV server.',
      ),
      507 => (
        WebDavErrorCode.insufficientStorage,
        'The WebDAV server is out of storage.',
      ),
      >= 500 => (
        WebDavErrorCode.server,
        'The WebDAV server returned an error (HTTP $status).',
      ),
      _ => (
        WebDavErrorCode.unexpected,
        'Unexpected reply from the WebDAV server (HTTP $status).',
      ),
    };
    return WebDavException(
      message,
      code: code,
      statusCode: status,
      location: location,
      sizeBytes: sizeBytes,
      cause: cause,
    );
  }

  static String _megabytes(int? bytes) =>
      bytes == null ? '?' : (bytes / (1024 * 1024)).round().toString();
}

/// The server presented a certificate that failed normal verification and
/// does not match the stored pin.
class WebDavUntrustedCertificateException extends WebDavException {
  WebDavUntrustedCertificateException(
    this.certificate, {
    this.pinnedSha256,
    super.cause,
  }) : super(
         pinnedSha256 == null
             ? 'The server certificate for ${certificate.host} is not trusted. '
                   'Open the WebDAV settings and test the connection to review it.'
             : 'The server certificate for ${certificate.host} changed since '
                   'you trusted it. Open the WebDAV settings and test the '
                   'connection to review it.',
         code: WebDavErrorCode.untrustedCertificate,
       );

  final WebDavCertificateDetails certificate;

  /// The pin stored when this was raised, or null when none was.
  final String? pinnedSha256;

  bool get pinMismatch => pinnedSha256 != null;
}
