import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Sign-in state of an account on THIS device (derived, never synced).
enum AccountStatus { signedIn, needsSignIn, unavailable }

/// One adapter per [AccountKind]. Adapters expose capabilities as extra
/// interfaces; features ask the registry for the capability they need.
abstract class AccountProviderAdapter {
  AccountKind get kind;

  /// Whether this device holds working credentials for [account].
  Future<AccountStatus> status(domain.ConnectedAccount account);

  /// Removes this device's credentials for [account]. Never touches the
  /// synced roster row (the account still exists in the library).
  Future<void> disconnect(domain.ConnectedAccount account);
}

/// The account can drive data sync.
abstract interface class SyncCapable {
  CloudStorageProvider syncProvider(domain.ConnectedAccount account);
}

/// The account can back a media object store.
abstract interface class MediaStoreCapable {
  Future<MediaObjectStore?> mediaObjectStore(domain.ConnectedAccount account);
}

/// Marker: the account is a media acquisition source (Lightroom now;
/// Immich/SMB per the program spec later).
abstract interface class MediaSourceCapable {}
