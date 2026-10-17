import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';

/// What a prefix holds, as read before joining or creating.
class LibraryProbe {
  const LibraryProbe({
    required this.exists,
    this.id,
    this.name,
    this.formatVersion = SharedLibraryLayout.formatVersion,
    this.encrypted = false,
    this.keyId,
    this.description,
  });

  final bool exists;

  /// From `info.json`; null for an encrypted library until it is unlocked.
  final String? description;
  final String? id;

  /// Null for an encrypted library until it is unlocked.
  final String? name;
  final int formatVersion;
  final bool encrypted;
  final String? keyId;

  bool get needsNewerApp =>
      exists && formatVersion > SharedLibraryLayout.formatVersion;

  /// Made by a test build before signing existed: it cannot be joined.
  bool get retired =>
      exists && formatVersion < SharedLibraryLayout.minFormatVersion;
}

typedef LibraryTransportFactory =
    Future<SharedLibraryTransport> Function({
      required domain.ConnectedAccount account,
      required String prefix,
    });

/// Leaving would leave the library without an owner while other members
/// remain: one of them must be made owner first.
class LastOwnerLeaveError extends StateError {
  LastOwnerLeaveError(String libraryId)
    : super('the only owner of $libraryId cannot leave its members');
}

/// A library already lives at the location a create was asked for.
class LibraryExistsError extends StateError {
  LibraryExistsError(String prefix)
    : super('A library already exists at $prefix');
}

/// The roles file of a library to join was not signed by one of its own
/// owners: whoever wrote it had no right to (issue #2567).
class UntrustedRolesError extends StateError {
  UntrustedRolesError(String prefix)
    : super('The roles of the library at $prefix are not signed by an owner');
}

/// The passphrase or recovery code typed in opens no keyslot of the
/// library.
class WrongPassphraseError extends StateError {
  WrongPassphraseError() : super('That passphrase does not open this library');
}

/// The recovery code typed in does not stand for the library's recovery
/// key.
class WrongRecoveryCodeError extends StateError {
  WrongRecoveryCodeError() : super('That is not the recovery code');
}

/// A library just made, and the recovery code its creator must keep.
class CreatedLibrary {
  const CreatedLibrary({required this.library, required this.recoveryCode});

  final SharedLibrary library;
  final String recoveryCode;
}

/// The member's card holds another key than the one an owner was shown and
/// compared: nothing is approved until they compare the new one.
class MemberKeyChangedError extends StateError {
  MemberKeyChangedError(String memberId)
    : super('the key on the card of $memberId changed');
}

/// The folder holds roles newer than any this device trusts (changes it
/// missed, or a file it refused): roles written from here would undo them.
/// Leaving and joining again takes up the newer roles when an owner signed
/// them.
class RolesOutOfDateError extends StateError {
  RolesOutOfDateError(String libraryId)
    : super('the roles of $libraryId changed since this device trusted them');
}

/// A role change would leave the library without an owner.
class LastOwnerDemoteError extends StateError {
  LastOwnerDemoteError(String libraryId)
    : super('the last owner of $libraryId cannot be demoted');
}
