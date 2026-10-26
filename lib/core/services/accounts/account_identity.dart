import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';

/// Namespace for deterministic connected-account ids. Frozen: every device
/// must derive the same id from the same endpoint, so changing this would
/// fork the roster across the fleet.
const String kConnectedAccountNamespace =
    'c622faae-974f-4310-a5e7-36c2fb773684';

/// Endpoint identity for an S3 account.
///
/// Uses [S3Config.displayHost] rather than the raw endpoint so AWS-proper
/// (empty endpoint, host derived from the region) and an explicit AWS
/// endpoint for one bucket resolve to a single account. Includes the prefix
/// so the sync and media-store roles stay separate accounts when they share
/// a bucket. Credentials are deliberately excluded: rotating a key must not
/// mint a new account.
String s3NaturalKey(S3Config config) =>
    '${config.displayHost}|${config.bucket}|${config.prefix}';

/// Endpoint identity for a WebDAV account: the DAV root (which carries the
/// user id where the address has one) plus the folder, so sync and media
/// on one server stay separate accounts. Credentials are excluded, so a
/// new app password does not mint a new account.
String webdavNaturalKey(WebDavConfig config) =>
    '${config.davRoot}|${config.folder}';

/// Endpoint identity for a Git account: the normalized clone address plus the
/// branch, so two branches of one repository stay separate accounts. The
/// token is excluded, so a new token does not mint a new account.
String gitNaturalKey(GitConfig config) => '${config.repoUrl}|${config.branch}';

/// Natural key for a kind that can only have one instance per library.
///
/// Null for [AccountKind.s3], [AccountKind.webdav] and [AccountKind.git]
/// (instance kinds: use [s3NaturalKey], [webdavNaturalKey] and
/// [gitNaturalKey]) and for
/// [AccountKind.adobeLightroom], whose ids are preserved from the v107
/// migration because Lightroom scan state and suggestion rows key on them.
String? naturalKeyForKind(AccountKind kind) => switch (kind) {
  AccountKind.icloud ||
  AccountKind.dropbox ||
  AccountKind.googledrive => kind.name,
  AccountKind.s3 ||
  AccountKind.webdav ||
  AccountKind.git ||
  AccountKind.adobeLightroom => null,
};

/// The deterministic id for an endpoint.
///
/// Two devices computing this for the same endpoint get the same primary
/// key, so sync's upsert-by-id merges them instead of unioning two rows.
/// This is why no unique index is needed: a unique constraint on a
/// replicated table would make an inbound sync insert throw rather than
/// merge.
String accountIdFor({required AccountKind kind, required String naturalKey}) =>
    const Uuid().v5(kConnectedAccountNamespace, '${kind.name}:$naturalKey');

/// Whether [id] was made by [accountIdFor] (a name-based UUIDv5) rather than
/// at random (the UUIDv4 rows from before deterministic ids).
bool isDeterministicAccountId(String id) => id.length == 36 && id[14] == '5';
