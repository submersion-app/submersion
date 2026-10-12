import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What a club library action that failed tells the user (issue #2567):
/// the refusals it knows in words, a storage failure as the provider puts
/// it, anything else as a plain try-again.
String libraryErrorText(AppLocalizations l10n, Object error) => switch (error) {
  LibraryExistsError() => l10n.sharedLibrary_connect_exists,
  LastOwnerDemoteError() => l10n.sharedLibrary_members_lastOwner,
  LastOwnerLeaveError() => l10n.sharedLibrary_library_lastOwnerLeave,
  CloudStorageException() => error.displayMessage,
  _ => l10n.common_error_tryAgain,
};
