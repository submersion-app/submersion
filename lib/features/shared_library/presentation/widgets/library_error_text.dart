import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/library_sync_error.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What a shared site library action that failed tells the user (issue #2567):
/// the refusals it knows in words, a WebDAV failure as the WebDAV settings
/// put it, another storage failure as the provider does, anything else as a
/// plain try-again.
String libraryErrorText(AppLocalizations l10n, Object error) => switch (error) {
  LibraryExistsError() => l10n.sharedLibrary_connect_exists,
  LastOwnerDemoteError() => l10n.sharedLibrary_members_lastOwner,
  MemberKeyChangedError() => l10n.sharedLibrary_members_keyChanged,
  RolesOutOfDateError() => l10n.sharedLibrary_members_rolesOutOfDate,
  LastOwnerLeaveError() => l10n.sharedLibrary_library_lastOwnerLeave,
  WrongRecoveryCodeError() => l10n.sharedLibrary_owner_wrongCode,
  WrongPassphraseError() => l10n.sharedLibrary_encrypted_wrong,
  LibraryLockedException() => l10n.sharedLibrary_encrypted_probe,
  UntrustedRolesError() => l10n.sharedLibrary_connect_untrusted,
  LibraryAccountMissingError() => l10n.sharedLibrary_syncError_accountMissing,
  LibraryAccountSignedOutError() =>
    l10n.sharedLibrary_syncError_accountSignedOut,
  LibraryAccountUnsupportedError() => l10n.sharedLibrary_connect_onlyS3Webdav,
  WebDavException() => webDavErrorText(l10n, error),
  CloudStorageException() => error.displayMessage,
  _ => l10n.common_error_tryAgain,
};

/// What a library's stored sync failure tells the user (issue #3563), in
/// their language. A storage message with no translation is shown as the
/// storage gave it.
String librarySyncErrorText(
  AppLocalizations l10n,
  LibrarySyncError error, {
  required String libraryName,
}) => switch (error.code) {
  LibrarySyncErrorCode.accountMissing =>
    l10n.sharedLibrary_syncError_accountMissing,
  LibrarySyncErrorCode.accountSignedOut =>
    l10n.sharedLibrary_syncError_accountSignedOut,
  LibrarySyncErrorCode.accountUnsupported =>
    l10n.sharedLibrary_connect_onlyS3Webdav,
  LibrarySyncErrorCode.notALibrary => l10n.sharedLibrary_syncError_notALibrary,
  LibrarySyncErrorCode.retired => l10n.sharedLibrary_retired,
  LibrarySyncErrorCode.needsNewerApp =>
    l10n.sharedLibrary_connect_needsNewerApp,
  LibrarySyncErrorCode.needsPassphrase => l10n.sharedLibrary_encrypted_locked(
    libraryName,
  ),
  LibrarySyncErrorCode.passphraseChanged =>
    l10n.sharedLibrary_encrypted_changed(libraryName),
  LibrarySyncErrorCode.webdav || LibrarySyncErrorCode.failed => switch ((
    error.webdav,
    error.detail,
  )) {
    (final WebDavException e, _) => webDavErrorText(l10n, e),
    (_, final String detail) => detail,
    _ => l10n.sharedLibrary_syncError_failed,
  },
};
