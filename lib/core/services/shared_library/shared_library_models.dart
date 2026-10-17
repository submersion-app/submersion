import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/sync/hlc.dart';

/// What a member may do in a shared site library (issue #2567).
enum SharedLibraryRole { reader, editor, owner }

/// The clock on one document field: when, by which member, and that
/// member's signature over the field (issue #2567). Two clocks are the same
/// edit when time and member match; the signature is not part of that.
class FieldClock extends Equatable {
  const FieldClock({required this.hlc, required this.memberId, this.sig});

  final Hlc hlc;
  final String memberId;
  final String? sig;

  factory FieldClock.fromJson(Map<String, dynamic> json) => FieldClock(
    hlc: Hlc.parse(json['hlc'] as String),
    memberId: json['memberId'] as String,
    sig: json['sig'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'hlc': hlc.toString(),
    'memberId': memberId,
    'sig': ?sig,
  };

  /// When the edit was made, as far as [hlc] tells: held within the dates
  /// a [DateTime] can hold, since a clock in a shared file may name any
  /// time at all.
  DateTime get editedAt => DateTime.fromMillisecondsSinceEpoch(
    hlc.physicalTime.clamp(0, _latestMs),
    isUtc: true,
  );

  static const _latestMs = 8640000000000000;

  /// The oldest clock there is, which [memberId] gives a field nobody's
  /// edit of is known: signed, it counts, yet any real edit wins over it.
  /// Its counter comes from [value], so two devices of one member claiming
  /// one field with different values never hold one clock for both: the
  /// same claim wins on every device.
  factory FieldClock.claim(String memberId, Object? value) {
    var counter = 0;
    try {
      final hash = sha256Hex(utf8.encode(canonicalJson(value)));
      counter = int.parse(hash.substring(0, 8), radix: 16) % 1000000;
    } on JsonUnsupportedObjectError {
      // No JSON holds the value; it never goes up, so any clock does.
    }
    return FieldClock(hlc: Hlc(0, counter, memberId), memberId: memberId);
  }

  /// Whether this clock marks an edit, not a [FieldClock.claim]: only those
  /// are shown as a site's history.
  bool get marksEdit => hlc.physicalTime > 0;

  FieldClock copyWith({String? memberId, String? sig, bool clearSig = false}) =>
      FieldClock(
        hlc: hlc,
        memberId: memberId ?? this.memberId,
        sig: clearSig ? null : sig ?? this.sig,
      );

  @override
  List<Object?> get props => [hlc, memberId];
}

/// The `recovery` entry of `roles.json`: the public key the library
/// recovery code stands for, and how to derive it again.
class RolesRecovery extends Equatable {
  const RolesRecovery({
    required this.publicKey,
    required this.salt,
    required this.kdf,
  });

  final String publicKey;
  final String salt;
  final Map<String, dynamic> kdf;

  static RolesRecovery? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final publicKey = raw['publicKey'];
    final salt = raw['salt'];
    final kdf = raw['kdf'];
    if (publicKey is! String || salt is! String || kdf is! Map) return null;
    return RolesRecovery(
      publicKey: publicKey,
      salt: salt,
      kdf: Map<String, dynamic>.from(kdf),
    );
  }

  Map<String, dynamic> toJson() => {
    'publicKey': publicKey,
    'salt': salt,
    'kdf': kdf,
  };

  @override
  List<Object?> get props => [publicKey, salt, kdf];
}

/// `roles.json`: owners and editors by member id (everyone else reads),
/// each approved member's public key, the recovery key, and the signature
/// of whoever wrote it (issue #2567). Unknown ids are kept verbatim so a
/// later join resolves them.
class SharedLibraryRoles extends Equatable {
  const SharedLibraryRoles({
    this.owners = const {},
    this.editors = const {},
    this.version = 0,
    this.approvedKeys = const {},
    this.recovery,
    this.reset = false,
    this.retired = const {},
    this.encryption,
    this.signedBy,
    this.signature,
  });

  final Set<String> owners;
  final Set<String> editors;

  /// Grows with every change, so an older signed file cannot be put back.
  final int version;

  /// Member id to the public key an owner approved for it.
  final Map<String, String> approvedKeys;
  final RolesRecovery? recovery;

  /// Written by "reset ownership": each member's device asks before
  /// trusting it.
  final bool reset;

  /// Keys that no longer edit, by member: an editing role that ended
  /// (left, demoted, role removed) or a key an owner replaced, and an
  /// owner's key when they stepped down. Each holds when it stopped; the
  /// edits it signed before then still count.
  final Map<String, List<({String key, int untilMs})>> retired;

  /// The library's encryption as an owner last set it: on under the key
  /// [LibraryEncryption.keyId], or off. Null for a library never encrypted
  /// since roles recorded it; the manifest then decides alone.
  final LibraryEncryption? encryption;

  /// [retired] as `(key, until)` pairs, for checking signatures.
  Map<String, List<(String, int)>> get retiredKeys => {
    for (final e in retired.entries)
      e.key: [for (final r in e.value) (r.key, r.untilMs)],
  };

  /// [retired] with [key] of [memberId] stopping at [at]; a key already
  /// retired keeps the later time.
  Map<String, List<({String key, int untilMs})>> _retiring(
    String memberId,
    String key,
    DateTime at,
  ) => {
    ...retired,
    memberId: [
      for (final r
          in retired[memberId] ?? const <({String key, int untilMs})>[])
        if (r.key != key) r,
      (key: key, untilMs: at.millisecondsSinceEpoch),
    ],
  };

  /// The member id that signed, or [recoverySigner].
  final String? signedBy;
  final String? signature;

  static const empty = SharedLibraryRoles();

  /// [signedBy] for a file signed with the recovery code's key.
  static const recoverySigner = 'recovery';

  factory SharedLibraryRoles.fromJson(Map<String, dynamic> json) =>
      SharedLibraryRoles(
        owners: _ids(json['owners']),
        editors: _ids(json['editors']),
        version: (json['version'] as num?)?.toInt() ?? 0,
        approvedKeys: {
          if (json['approvedKeys'] case final Map keys)
            for (final e in keys.entries)
              if (e.key is String && e.value is String)
                e.key as String: e.value as String,
        },
        recovery: RolesRecovery.fromJson(json['recovery']),
        reset: json['reset'] == true,
        retired: {
          if (json['retired'] case final Map raw)
            for (final e in raw.entries)
              if (e.key is String && e.value is List)
                e.key as String: [
                  for (final r in e.value as List)
                    if (r case {
                      'key': final String key,
                      'until': final num until,
                    })
                      (key: key, untilMs: until.toInt()),
                ],
        },
        encryption: LibraryEncryption.fromJson(json['encryption']),
        signedBy: json['signedBy'] as String?,
        signature: json['signature'] as String?,
      );

  static Set<String> _ids(Object? raw) =>
      raw is List ? raw.whereType<String>().toSet() : const {};

  /// Everything the signature covers: all but the signature itself.
  Map<String, dynamic> unsignedJson() => {
    'owners': owners.toList()..sort(),
    'editors': editors.toList()..sort(),
    'version': version,
    'approvedKeys': approvedKeys,
    'recovery': ?recovery?.toJson(),
    'reset': reset,
    // Absent when empty, so roles written before it sign as they did.
    'retired': ?(retired.isEmpty
        ? null
        : {
            for (final e in retired.entries)
              e.key: [
                for (final r in e.value) {'key': r.key, 'until': r.untilMs},
              ],
          }),
    // Absent when unset, as for [retired].
    'encryption': ?encryption?.toJson(),
    'signedBy': ?signedBy,
  };

  Map<String, dynamic> toJson() => {...unsignedJson(), 'signature': ?signature};

  /// What the signature covers: [unsignedJson] bound to [libraryId], so a
  /// file signed for one library never counts in another, even where the
  /// same person owns both with the same key.
  List<int> signedMessage(String libraryId) =>
      utf8.encode('ssl-roles:v1\n$libraryId\n${canonicalJson(unsignedJson())}');

  /// This file, for the library [libraryId], signed by [signedBy] with
  /// [key].
  Future<SharedLibraryRoles> signed({
    required String libraryId,
    required String signedBy,
    required LibrarySigningKey key,
  }) async {
    final unsigned = copyWith(signedBy: signedBy, clearSignature: true);
    final signature = await LibrarySigner.sign(
      key,
      unsigned.signedMessage(libraryId),
    );
    return unsigned.copyWith(signature: signature);
  }

  SharedLibraryRoles copyWith({
    Set<String>? owners,
    Set<String>? editors,
    int? version,
    Map<String, String>? approvedKeys,
    RolesRecovery? recovery,
    bool clearRecovery = false,
    bool? reset,
    Map<String, List<({String key, int untilMs})>>? retired,
    LibraryEncryption? encryption,
    bool clearEncryption = false,
    String? signedBy,
    String? signature,
    bool clearSignature = false,
  }) => SharedLibraryRoles(
    owners: owners ?? this.owners,
    editors: editors ?? this.editors,
    version: version ?? this.version,
    approvedKeys: approvedKeys ?? this.approvedKeys,
    recovery: clearRecovery ? null : recovery ?? this.recovery,
    reset: reset ?? this.reset,
    retired: retired ?? this.retired,
    encryption: clearEncryption ? null : encryption ?? this.encryption,
    signedBy: signedBy ?? this.signedBy,
    signature: clearSignature ? null : signature ?? this.signature,
  );

  /// The approved keys whose site edits count: owners' and editors'. A
  /// reader's key signs suggestions only, whatever their storage key may
  /// write.
  Map<String, String> get editingKeys => {
    for (final e in approvedKeys.entries)
      if (roleOf(e.key) != SharedLibraryRole.reader) e.key: e.value,
  };

  /// Whether [other] proves and holds back the same field edits as these
  /// roles: the same editing keys, retired keys and editing members. Only
  /// a change that moves a verdict makes members read every site again; a
  /// reader's approval, a new recovery code or the encryption record do
  /// not.
  bool judgesFieldsAs(SharedLibraryRoles other) =>
      const MapEquality<String, String>().equals(
        editingKeys,
        other.editingKeys,
      ) &&
      const DeepCollectionEquality().equals(retired, other.retired) &&
      const SetEquality<String>().equals(
        {...owners, ...editors},
        {...other.owners, ...other.editors},
      );

  SharedLibraryRole roleOf(String memberId) {
    if (owners.contains(memberId)) return SharedLibraryRole.owner;
    if (editors.contains(memberId)) return SharedLibraryRole.editor;
    return SharedLibraryRole.reader;
  }

  /// [memberId] moved to [role] at [at]. A member leaving an editing role
  /// for reader is recorded in [retired], so the edits they signed until
  /// then keep counting; so is an owner stepping down, so roles they sign
  /// doing it still prove themselves to a device new to the library. The
  /// version and signature are the caller's to set.
  SharedLibraryRoles changeRole(
    String memberId,
    SharedLibraryRole role, {
    required DateTime at,
  }) {
    final moved = withRole(memberId, role);
    final key = approvedKeys[memberId];
    final from = roleOf(memberId);
    if (key == null ||
        from == role ||
        from == SharedLibraryRole.reader ||
        role == SharedLibraryRole.owner) {
      return moved;
    }
    return moved.copyWith(retired: _retiring(memberId, key, at));
  }

  /// Roles that make [ownerId] (with [key]) the only owner, marked as an
  /// ownership reset. Every editor's and owner's key is retired at [at]:
  /// the library they built keeps counting for members who join after.
  SharedLibraryRoles resetTo(
    String ownerId,
    String key, {
    required int version,
    required DateTime at,
  }) {
    var retiring = retired;
    for (final id in {...owners, ...editors}) {
      final old = approvedKeys[id];
      if (old == null || id == ownerId) continue;
      retiring = copyWith(retired: retiring)._retiring(id, old, at);
    }
    return SharedLibraryRoles(
      version: version,
      owners: {ownerId},
      approvedKeys: {ownerId: key},
      retired: retiring,
      encryption: encryption,
      reset: true,
    );
  }

  /// [memberId]'s [key] approved at [at]. An editor's or owner's earlier
  /// key, when it differs, is retired so what it signed keeps counting.
  SharedLibraryRoles approveKey(
    String memberId,
    String key, {
    required DateTime at,
  }) {
    final old = approvedKeys[memberId];
    final approved = copyWith(approvedKeys: {...approvedKeys, memberId: key});
    if (old == null ||
        old == key ||
        roleOf(memberId) == SharedLibraryRole.reader) {
      return approved;
    }
    return approved.copyWith(retired: _retiring(memberId, old, at));
  }

  /// [memberId] moved to [role]; the version and signature are the
  /// caller's to set.
  SharedLibraryRoles withRole(String memberId, SharedLibraryRole role) {
    final newOwners = {...owners}..remove(memberId);
    final newEditors = {...editors}..remove(memberId);
    switch (role) {
      case SharedLibraryRole.owner:
        newOwners.add(memberId);
      case SharedLibraryRole.editor:
        newEditors.add(memberId);
      case SharedLibraryRole.reader:
        break;
    }
    return copyWith(owners: newOwners, editors: newEditors);
  }

  @override
  List<Object?> get props => [
    owners,
    editors,
    version,
    approvedKeys,
    recovery,
    reset,
    retired,
    encryption,
    signedBy,
    signature,
  ];
}

/// A library's encryption as an owner set it in `roles.json` (issue #2567):
/// [on] under the key [keyId], or off. The manifest holds the same but is
/// not signed, so it cannot turn encryption off on its own.
class LibraryEncryption extends Equatable {
  const LibraryEncryption({required this.on, this.keyId});

  final bool on;
  final String? keyId;

  static LibraryEncryption? fromJson(Object? raw) => switch (raw) {
    {'on': final bool on} => LibraryEncryption(
      on: on,
      keyId: switch (raw['keyId']) {
        final String id => id,
        _ => null,
      },
    ),
    _ => null,
  };

  Map<String, dynamic> toJson() => {'on': on, 'keyId': ?keyId};

  @override
  List<Object?> get props => [on, keyId];
}

/// How a library's files are written, as [libraryEncryptionOf] settles it.
typedef LibraryEncryptionState = ({
  bool encrypted,
  String? keyId,
  bool rewriting,
  bool overruled,
});

/// How a library's files are written, from its [manifest] and the roles a
/// device trusts ([trusted]): what the manifest says, unless it says off
/// while the trusted roles, which only an owner signs, say on. Then the
/// roles stand ([overruled]): whoever wrote that manifest did not turn
/// encryption off, and nothing is written plain or a key dropped for it.
LibraryEncryptionState libraryEncryptionOf(
  Map<String, dynamic>? manifest,
  SharedLibraryRoles trusted,
) {
  final declared = manifest?['encrypted'] == true;
  final recorded = trusted.encryption;
  if (!declared && recorded != null && recorded.on) {
    return (
      encrypted: true,
      keyId: recorded.keyId,
      rewriting: false,
      overruled: true,
    );
  }
  return (
    encrypted: declared,
    keyId: switch (manifest?['keyId']) {
      final String id => id,
      _ => null,
    },
    rewriting: manifest?[SharedLibraryLayout.rewritingFlag] == true,
    overruled: false,
  );
}

/// The newest of [clocks] that marks an edit, or null when none does: the
/// last edit of a site, which its attribution names.
FieldClock? newestClockOf(Iterable<FieldClock> clocks) {
  FieldClock? newest;
  for (final c in clocks) {
    if (!c.marksEdit) continue;
    if (newest == null || c.hlc.compareTo(newest.hlc) > 0) newest = c;
  }
  return newest;
}

/// The role the UI honours: the listed role, capped at reader when the
/// storage refused a write.
SharedLibraryRole effectiveRole({
  required SharedLibraryRole listed,
  required bool readOnlyDetected,
}) => readOnlyDetected ? SharedLibraryRole.reader : listed;

/// A member card from `members/<memberId>.json`, signed by the member's own
/// key (issue #2567). [cardVerified] is set when the card was read: the
/// signature matches its own [publicKey]. Whether that key is approved is
/// the roles' business ([isApprovedMember]).
class SharedLibraryMember extends Equatable {
  const SharedLibraryMember({
    required this.memberId,
    required this.displayName,
    required this.joinedAt,
    this.publicKey,
    this.signature,
    this.cardVerified = false,
  });

  final String memberId;
  final String displayName;
  final DateTime joinedAt;
  final String? publicKey;
  final String? signature;
  final bool cardVerified;

  /// A card for [memberId], signed with [key].
  static Future<SharedLibraryMember> signed({
    required String memberId,
    required String displayName,
    required DateTime joinedAt,
    required LibrarySigningKey key,
  }) async {
    final unsigned = SharedLibraryMember(
      memberId: memberId,
      displayName: displayName,
      joinedAt: joinedAt,
      publicKey: key.publicKey,
    );
    return SharedLibraryMember(
      memberId: memberId,
      displayName: displayName,
      joinedAt: joinedAt,
      publicKey: key.publicKey,
      signature: await LibrarySigner.sign(key, unsigned.signedBytes()),
      cardVerified: true,
    );
  }

  /// What the card's signature covers.
  List<int> signedBytes() => utf8.encode(
    canonicalJson({
      'memberId': memberId,
      'displayName': displayName,
      'joinedAt': joinedAt.toUtc().toIso8601String(),
      'publicKey': publicKey,
    }),
  );

  /// Whether the signature matches the card's own key.
  Future<bool> verify() async =>
      publicKey != null &&
      await LibrarySigner.verify(
        publicKey: publicKey!,
        message: signedBytes(),
        signature: signature,
      );

  factory SharedLibraryMember.fromJson(
    String memberId,
    Map<String, dynamic> json,
  ) => SharedLibraryMember(
    memberId: memberId,
    displayName: (json['displayName'] as String?) ?? '',
    joinedAt:
        DateTime.tryParse((json['joinedAt'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    publicKey: json['publicKey'] as String?,
    signature: json['signature'] as String?,
  );

  Map<String, dynamic> toJson({required String appVersion}) => {
    'displayName': displayName,
    'joinedAt': joinedAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'publicKey': ?publicKey,
    'signature': ?signature,
  };

  SharedLibraryMember copyWith({bool? cardVerified}) => SharedLibraryMember(
    memberId: memberId,
    displayName: displayName,
    joinedAt: joinedAt,
    publicKey: publicKey,
    signature: signature,
    cardVerified: cardVerified ?? this.cardVerified,
  );

  @override
  List<Object?> get props => [
    memberId,
    displayName,
    joinedAt,
    publicKey,
    signature,
    cardVerified,
  ];
}

/// Whether [m]'s card is genuine and its key is the one [roles] approved
/// for it: only then do its edits and suggestions count (issue #2567).
bool isApprovedMember(SharedLibraryMember m, SharedLibraryRoles roles) =>
    m.cardVerified &&
    m.publicKey != null &&
    roles.approvedKeys[m.memberId] == m.publicKey;

/// A shared site library connected on this device.
class SharedLibrary extends Equatable {
  const SharedLibrary({
    required this.id,
    required this.name,
    required this.connectedAccountId,
    required this.prefix,
    this.formatVersion = 1,
    this.readOnlyDetected = false,
    this.roles = SharedLibraryRoles.empty,
    this.lastSyncAt,
    this.lastError,
    this.rolesRejected = false,
    this.pendingRoles,
    this.encrypted = false,
    this.keyId,
    this.lastAutoBackupAt,
    this.description,
  });

  final String id;
  final String name;

  /// What the library is for, from its `info.json` (issue #3389).
  final String? description;
  final String connectedAccountId;
  final String prefix;
  final int formatVersion;
  final bool readOnlyDetected;

  /// The last `roles.json` this device trusted.
  final SharedLibraryRoles roles;
  final DateTime? lastSyncAt;
  final String? lastError;

  /// The folder holds a `roles.json` this device refused.
  final bool rolesRejected;

  /// An ownership reset waiting for this member's answer.
  final SharedLibraryRoles? pendingRoles;

  /// Whether writes made here go nowhere: the storage refused one, the
  /// folder holds roles this device refused, or an ownership reset waits
  /// for this member's answer. Site edits then count as a reader's.
  bool get writesHeld =>
      readOnlyDetected || rolesRejected || pendingRoles != null;

  /// The manifest's encryption state as last read.
  final bool encrypted;
  final String? keyId;

  /// When this device last made an automatic backup.
  final DateTime? lastAutoBackupAt;

  SharedLibrary copyWith({
    String? name,
    bool? readOnlyDetected,
    SharedLibraryRoles? roles,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearLastError = false,
    bool? rolesRejected,
    String? description,
    bool clearDescription = false,
  }) => SharedLibrary(
    id: id,
    name: name ?? this.name,
    description: clearDescription ? null : (description ?? this.description),
    connectedAccountId: connectedAccountId,
    prefix: prefix,
    formatVersion: formatVersion,
    readOnlyDetected: readOnlyDetected ?? this.readOnlyDetected,
    roles: roles ?? this.roles,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    lastError: clearLastError ? null : (lastError ?? this.lastError),
    rolesRejected: rolesRejected ?? this.rolesRejected,
    pendingRoles: pendingRoles,
    encrypted: encrypted,
    keyId: keyId,
    lastAutoBackupAt: lastAutoBackupAt,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    connectedAccountId,
    prefix,
    formatVersion,
    readOnlyDetected,
    roles,
    lastSyncAt,
    lastError,
    rolesRejected,
    pendingRoles,
    encrypted,
    keyId,
    lastAutoBackupAt,
    description,
  ];
}

/// A diver profile's membership of a library; synced across the profile's
/// devices. Carries a location hint and the profile's keys (its signing key,
/// and the library key once unlocked), never storage credentials.
class SharedLibraryMembership extends Equatable {
  const SharedLibraryMembership({
    required this.id,
    required this.diverId,
    required this.libraryId,
    required this.memberId,
    required this.displayName,
    required this.libraryName,
    required this.backendKind,
    this.locationHint = '',
    this.signingKey,
    this.libraryKeyId,
    this.libraryKey,
  });

  final String id;
  final String diverId;
  final String libraryId;
  final String memberId;
  final String displayName;
  final String libraryName;
  final String backendKind;
  final String locationHint;

  /// The profile's signing key, the same on all of its memberships.
  final LibrarySigningKey? signingKey;

  /// The unlocked key of an encrypted library, base64, with its id.
  final String? libraryKeyId;
  final String? libraryKey;

  /// The folder prefix [locationHint] names (`<account label>: <prefix>`),
  /// to prefill Connect on a device that has not connected the library.
  String get prefixHint {
    final at = locationHint.indexOf(': ');
    return at < 0 ? '' : locationHint.substring(at + 2);
  }

  SharedLibraryMembership copyWith({
    String? displayName,
    String? libraryName,
    String? backendKind,
    String? locationHint,
    LibrarySigningKey? signingKey,
    String? libraryKeyId,
    String? libraryKey,
  }) => SharedLibraryMembership(
    id: id,
    diverId: diverId,
    libraryId: libraryId,
    memberId: memberId,
    displayName: displayName ?? this.displayName,
    libraryName: libraryName ?? this.libraryName,
    backendKind: backendKind ?? this.backendKind,
    locationHint: locationHint ?? this.locationHint,
    signingKey: signingKey ?? this.signingKey,
    libraryKeyId: libraryKeyId ?? this.libraryKeyId,
    libraryKey: libraryKey ?? this.libraryKey,
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    libraryId,
    memberId,
    displayName,
    libraryName,
    backendKind,
    locationHint,
    signingKey?.publicKey,
    libraryKeyId,
  ];
}

/// File and folder names inside a library's folder.
abstract final class SharedLibraryLayout {
  /// The folder at the top of the storage that holds every library, beside
  /// `submersion-sync` and `submersion-media`.
  static const librariesDir = 'submersion-sites';

  /// A library's own subfolders: no library folder may start with one, so
  /// a library at the top of [librariesDir] never shares a folder with
  /// another library.
  static const reservedFolders = {
    membersDir,
    sitesDir,
    suggestionsDir,
    'backups',
  };
  static const manifestFile = 'submersion-shared-library.json';

  /// Manifest flag set while an owner rewrites every file into a new form
  /// (encryption on, off or a new key): until it is cleared no device drops
  /// its key, and an owner's sync finishes a rewrite that was cut short.
  static const rewritingFlag = 'rewriting';

  static final _libraryId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

  /// Whether [id], read from a library's manifest, is safe to name a local
  /// folder with (the library's backups): no path separators or dot
  /// segments, nothing that could leave the folder it is joined into.
  static bool isValidLibraryId(String id) => _libraryId.hasMatch(id);
  static const rolesFile = 'roles.json';

  /// The library's name, kept apart from the manifest so it can be sealed
  /// with the rest when the library is encrypted.
  static const infoFile = 'info.json';

  /// The wrapped library key of an encrypted library; always plain.
  static const keyslotsFile = 'keyslots.json';

  /// The library's earlier keys, sealed under the key [keyId] names: a
  /// file left under an old key (a passphrase change cut short, or a
  /// member's upload during one) still opens, and an owner's sync re-seals
  /// it. One file per sealing key, so a change cut short before the library
  /// switched leaves the current key's list as it was.
  static String previousKeysFileFor(String keyId) =>
      '$previousKeysPrefix${keyId.toLowerCase()}.bin';
  static const previousKeysPrefix = 'previous-keys-';
  static const backupsDir = 'backups';
  static const membersDir = 'members';
  static const sitesDir = 'sites';
  static const suggestionsDir = 'suggestions';

  /// 2: signed roles, cards, edits and suggestions, `info.json`, optional
  /// encryption (issue #2567).
  static const formatVersion = 2;

  /// Version 1 came only from test builds before signing: refused.
  static const minFormatVersion = 2;

  static String memberFile(String memberId) => '$membersDir/$memberId.json';
  static String siteFile(String siteId) => '$sitesDir/$siteId.json';
  static String suggestionFile(String id) => '$suggestionsDir/$id.json';
}
