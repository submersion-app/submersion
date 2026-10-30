import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

/// The sign-in is gone and a silent refresh found no grant to replace it.
CloudStorageException driveSignInExpired(Object cause) =>
    CloudAccessRefusedException(
      'Google Drive sign-in expired. Please sign in again.',
      cause,
    );

/// The refresh itself failed, which a dropped network does as well as
/// anything else, so it says nothing about the account (issue #3811). Were
/// the grant really gone, the sign-out shows at the next isAuthenticated.
CloudStorageException driveRefreshFailed(Object cause) => CloudStorageException(
  'Could not refresh the Google Drive sign-in. Check your connection and try '
  'again.',
  cause,
);

/// The 403 reasons that mean this account may not use Drive. An allowlist: a
/// reason it does not name (a quota, a rate limit, one Google adds later) must
/// not ask a diver to sign in again.
const driveRefusedReasons = {
  'insufficientPermissions',
  'insufficientFilePermissions',
  'ACCESS_TOKEN_SCOPE_INSUFFICIENT',
  'authError',
};
