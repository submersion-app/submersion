import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';

/// Why a Git operation failed. The settings UI localizes from this; the
/// English [CloudStorageException.message] is for the sync status line and
/// logs.
enum GitErrorCode {
  invalidConfig,
  unauthorized,
  forbidden,
  notFound,
  notGit,
  unreachable,
  untrustedCertificate,

  /// The branch tip moved since this device last fetched it.
  staleTip,

  /// The host refused a history reset because the branch is protected.
  protectedBranch,
  tooLarge,
  rateLimited,

  /// The branch exists and is not one Submersion created.
  branchHasOtherContent,

  /// The repository is public and encrypted sync is off.
  publicRepoUnencrypted,

  /// The branch's file index is from a newer Submersion version.
  indexUnreadable,
  server,
  unexpected,
}

class GitException extends CloudStorageException {
  GitException(
    String message, {
    required this.code,
    this.statusCode,
    this.host,
    this.sizeBytes,
    this.serverReason,
    Object? cause,
  }) : super(message, cause);

  final GitErrorCode code;
  final int? statusCode;

  /// The server that could not be reached, for [GitErrorCode.unreachable].
  final String? host;

  /// The refused file's size, for [GitErrorCode.tooLarge], when known.
  final int? sizeBytes;

  /// The host's own words: a push `ng` reason or a side-band error line.
  final String? serverReason;

  @override
  String toString() =>
      'GitException(${code.name}): $message'
      '${serverReason == null ? '' : ' [$serverReason]'}';
}

/// A thin pack's delta against an object this device does not hold: one it
/// pushed and never kept, or one evicted since. A fetch without haves gets
/// whole objects instead.
class GitDeltaBaseMissingException extends GitException {
  GitDeltaBaseMissingException(this.baseId)
    : super(
        'The server sent a corrupt pack (delta base $baseId missing).',
        code: GitErrorCode.unexpected,
      );

  final GitObjectId baseId;
}

/// A TLS certificate the platform does not trust and the user has not
/// pinned. Carries what the trust dialog shows.
class GitUntrustedCertificateException extends GitException {
  GitUntrustedCertificateException(this.certificate, {super.cause})
    : super(
        'The certificate of ${certificate.host} is not trusted.',
        code: GitErrorCode.untrustedCertificate,
        host: certificate.host,
      );

  final WebDavCertificateDetails certificate;
}
