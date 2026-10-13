import 'package:collection/collection.dart';

import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// What a device does with a `roles.json` it finds (issue #2567).
enum RolesVerdict {
  /// Signed by an owner (or the recovery key) of the trusted roles, and newer.
  trusted,

  /// Anything else: the trusted roles stay, and the library page warns.
  rejected,

  /// A self-consistent ownership reset: the member is asked.
  resetPending,
}

/// The key [authority] lets [signedBy] sign roles with: an owner's approved
/// key, or the recovery key; null when it gives [signedBy] no such right.
String? _signerKey(SharedLibraryRoles authority, String? signedBy) {
  if (signedBy == null) return null;
  if (signedBy == SharedLibraryRoles.recoverySigner) {
    return authority.recovery?.publicKey;
  }
  if (!authority.owners.contains(signedBy)) return null;
  return authority.approvedKeys[signedBy];
}

Future<bool> _signedWith(
  SharedLibraryRoles roles,
  String? key,
  String libraryId,
) async =>
    key != null &&
    await LibrarySigner.verify(
      publicKey: key,
      message: roles.signedMessage(libraryId),
      signature: roles.signature,
    );

/// Whether [incoming] may replace [trusted] on this device, for the
/// library [libraryId]. Before any roles are trusted (just joined), a
/// self-consistent file is taken as found.
Future<RolesVerdict> judgeRoles({
  required SharedLibraryRoles trusted,
  required SharedLibraryRoles incoming,
  required String libraryId,
}) async {
  if (trusted.version == 0) {
    return await isSelfConsistent(incoming, libraryId: libraryId)
        ? RolesVerdict.trusted
        : RolesVerdict.rejected;
  }
  if (incoming.version > trusted.version &&
      await _signedWith(
        incoming,
        _signerKey(trusted, incoming.signedBy),
        libraryId,
      )) {
    return RolesVerdict.trusted;
  }
  if (incoming.version > trusted.version &&
      await _isGenuineReset(incoming, libraryId)) {
    return RolesVerdict.resetPending;
  }
  return RolesVerdict.rejected;
}

/// An ownership reset as only "reset ownership" writes one: a single owner,
/// who signed it with the one key it approves. The member is shown that
/// owner's name and key to check, so nobody else may stand behind it.
Future<bool> _isGenuineReset(SharedLibraryRoles roles, String libraryId) async {
  final signer = roles.signedBy;
  return roles.reset &&
      signer != null &&
      roles.owners.length == 1 &&
      roles.owners.single == signer &&
      await _signedWith(roles, roles.approvedKeys[signer], libraryId);
}

/// Signed by one of its own owners or its own recovery key: all a joining
/// device, with nothing trusted yet, can check. A file an owner signed as
/// they left lists them as retired, no longer as an owner, and counts too:
/// without it nobody could join until another owner rewrote the roles.
/// (A device that trusts roles already never takes one from a retired
/// member: [judgeRoles] asks for an owner of the roles it trusts.)
Future<bool> isSelfConsistent(
  SharedLibraryRoles roles, {
  required String libraryId,
}) async =>
    await _signedWith(roles, _signerKey(roles, roles.signedBy), libraryId) ||
    await _signedWith(
      roles,
      roles.retired[roles.signedBy]?.lastOrNull?.key,
      libraryId,
    );
