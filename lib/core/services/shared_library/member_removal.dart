import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// An owner's signed record that [memberId] was removed from a shared site
/// library (issue #3481). It sits beside the member cards as
/// `removed-<memberId>.json`, outside `roles.json`: devices on v1.8.2
/// re-serialize the roles to check their signature, so a new roles field
/// would make them refuse every roles file written after a removal.
class MemberRemoval extends Equatable {
  const MemberRemoval({
    required this.memberId,
    required this.displayName,
    this.publicKey,
    required this.removedAt,
    required this.removedBy,
    this.signature,
  });

  final String memberId;

  /// The name on the member's card when they were removed, so the Removed
  /// list can name them once the card is gone.
  final String displayName;

  /// The key the owners had approved for the member, when there was one:
  /// their suggestions from before [removedAt] still verify with it.
  final String? publicKey;
  final DateTime removedAt;

  /// The owner who removed them.
  final String removedBy;
  final String? signature;

  /// A record for the library [libraryId], signed with [key] (the key of
  /// [removedBy]).
  static Future<MemberRemoval> signed({
    required String libraryId,
    required String memberId,
    required String displayName,
    String? publicKey,
    required DateTime removedAt,
    required String removedBy,
    required LibrarySigningKey key,
  }) async {
    final unsigned = MemberRemoval(
      memberId: memberId,
      displayName: displayName,
      publicKey: publicKey,
      removedAt: removedAt.toUtc(),
      removedBy: removedBy,
    );
    return unsigned._withSignature(
      await LibrarySigner.sign(key, unsigned._signedMessage(libraryId)),
    );
  }

  MemberRemoval _withSignature(String signature) => MemberRemoval(
    memberId: memberId,
    displayName: displayName,
    publicKey: publicKey,
    removedAt: removedAt,
    removedBy: removedBy,
    signature: signature,
  );

  Map<String, dynamic> _unsignedJson() => {
    'memberId': memberId,
    'displayName': displayName,
    'publicKey': ?publicKey,
    'removedAt': removedAt.millisecondsSinceEpoch,
    'removedBy': removedBy,
  };

  /// What the signature covers, bound to [libraryId] as roles are.
  List<int> _signedMessage(String libraryId) => utf8.encode(
    'ssl-removal:v1\n$libraryId\n${canonicalJson(_unsignedJson())}',
  );

  Map<String, dynamic> toJson() => {
    ..._unsignedJson(),
    'signature': ?signature,
  };

  /// The largest time a [DateTime] holds, in milliseconds either side of
  /// the epoch.
  static const _maxMs = 8640000000000000;

  /// Null for anything that is not a well-formed record.
  static MemberRemoval? fromJson(Object? raw) {
    if (raw case {
      'memberId': final String memberId,
      'displayName': final String displayName,
      'removedAt': final num removedAt,
      'removedBy': final String removedBy,
    }) {
      // A time no DateTime holds (out of range, NaN, infinite) is no
      // record: skipped like any other malformed one, never a failed sync.
      if (!removedAt.isFinite || removedAt.abs() > _maxMs) return null;
      final key = raw['publicKey'];
      final signature = raw['signature'];
      return MemberRemoval(
        memberId: memberId,
        displayName: displayName,
        publicKey: key is String ? key : null,
        removedAt: DateTime.fromMillisecondsSinceEpoch(
          removedAt.toInt(),
          isUtc: true,
        ),
        removedBy: removedBy,
        signature: signature is String ? signature : null,
      );
    }
    return null;
  }

  /// Whether an owner in [roles] signed this record for [libraryId]. A
  /// record by anyone else (an editor who may write member files) counts
  /// for nothing.
  Future<bool> verify(String libraryId, SharedLibraryRoles roles) async {
    final key = roles.approvedKeys[removedBy];
    if (key == null || !roles.owners.contains(removedBy)) return false;
    return LibrarySigner.verify(
      publicKey: key,
      message: _signedMessage(libraryId),
      signature: signature,
    );
  }

  @override
  List<Object?> get props => [
    memberId,
    displayName,
    publicKey,
    removedAt,
    removedBy,
    signature,
  ];
}

/// The records among [records] that an owner in [roles] signed.
Future<List<MemberRemoval>> validRemovals(
  Iterable<MemberRemoval> records,
  String libraryId,
  SharedLibraryRoles roles,
) async => [
  for (final r in records)
    if (await r.verify(libraryId, roles)) r,
];

extension MemberRemovalRoles on SharedLibraryRoles {
  /// [memberId] removed at [at]: moved to reader, with an editor's or
  /// owner's key retired at [at] by [changeRole] so the edits they signed
  /// until then keep counting, and their approval dropped. A reader's key
  /// is not retired: a reader's own field edits never counted. The
  /// version and signature are the caller's to set.
  SharedLibraryRoles removing(String memberId, {required DateTime at}) {
    final moved = changeRole(memberId, SharedLibraryRole.reader, at: at);
    return moved.copyWith(
      approvedKeys: {...moved.approvedKeys}..remove(memberId),
    );
  }
}
