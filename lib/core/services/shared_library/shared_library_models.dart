import 'package:equatable/equatable.dart';

import 'package:submersion/core/services/sync/hlc.dart';

/// What a member may do in a club library (issue #2567).
enum SharedLibraryRole { reader, editor, owner }

/// The clock on one document field: when, and by which member.
class FieldClock extends Equatable {
  const FieldClock({required this.hlc, required this.memberId});

  final Hlc hlc;
  final String memberId;

  factory FieldClock.fromJson(Map<String, dynamic> json) => FieldClock(
    hlc: Hlc.parse(json['hlc'] as String),
    memberId: json['memberId'] as String,
  );

  Map<String, dynamic> toJson() => {
    'hlc': hlc.toString(),
    'memberId': memberId,
  };

  @override
  List<Object?> get props => [hlc, memberId];
}

/// `roles.json`: owners and editors by member id; everyone else reads.
/// Unknown ids are kept verbatim so a later join resolves them.
class SharedLibraryRoles extends Equatable {
  const SharedLibraryRoles({this.owners = const {}, this.editors = const {}});

  final Set<String> owners;
  final Set<String> editors;

  static const empty = SharedLibraryRoles();

  factory SharedLibraryRoles.fromJson(Map<String, dynamic> json) =>
      SharedLibraryRoles(
        owners: _ids(json['owners']),
        editors: _ids(json['editors']),
      );

  static Set<String> _ids(Object? raw) =>
      raw is List ? raw.whereType<String>().toSet() : const {};

  Map<String, dynamic> toJson() => {
    'owners': owners.toList()..sort(),
    'editors': editors.toList()..sort(),
  };

  SharedLibraryRole roleOf(String memberId) {
    if (owners.contains(memberId)) return SharedLibraryRole.owner;
    if (editors.contains(memberId)) return SharedLibraryRole.editor;
    return SharedLibraryRole.reader;
  }

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
    return SharedLibraryRoles(owners: newOwners, editors: newEditors);
  }

  @override
  List<Object?> get props => [owners, editors];
}

/// The role the UI honours: the listed role, capped at reader when the
/// storage refused a write.
/// The newest of [clocks], or null when there are none: the last edit of a
/// site, which its attribution names.
FieldClock? newestClockOf(Iterable<FieldClock> clocks) {
  FieldClock? newest;
  for (final c in clocks) {
    if (newest == null || c.hlc.compareTo(newest.hlc) > 0) newest = c;
  }
  return newest;
}

SharedLibraryRole effectiveRole({
  required SharedLibraryRole listed,
  required bool readOnlyDetected,
}) => readOnlyDetected ? SharedLibraryRole.reader : listed;

/// A member card from `members/<memberId>.json`.
class SharedLibraryMember extends Equatable {
  const SharedLibraryMember({
    required this.memberId,
    required this.displayName,
    required this.joinedAt,
  });

  final String memberId;
  final String displayName;
  final DateTime joinedAt;

  factory SharedLibraryMember.fromJson(
    String memberId,
    Map<String, dynamic> json,
  ) => SharedLibraryMember(
    memberId: memberId,
    displayName: (json['displayName'] as String?) ?? '',
    joinedAt:
        DateTime.tryParse((json['joinedAt'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  Map<String, dynamic> toJson({required String appVersion}) => {
    'displayName': displayName,
    'joinedAt': joinedAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
  };

  @override
  List<Object?> get props => [memberId, displayName, joinedAt];
}

/// A club library connected on this device.
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
  });

  final String id;
  final String name;
  final String connectedAccountId;
  final String prefix;
  final int formatVersion;
  final bool readOnlyDetected;
  final SharedLibraryRoles roles;
  final DateTime? lastSyncAt;
  final String? lastError;

  SharedLibrary copyWith({
    String? name,
    bool? readOnlyDetected,
    SharedLibraryRoles? roles,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearLastError = false,
  }) => SharedLibrary(
    id: id,
    name: name ?? this.name,
    connectedAccountId: connectedAccountId,
    prefix: prefix,
    formatVersion: formatVersion,
    readOnlyDetected: readOnlyDetected ?? this.readOnlyDetected,
    roles: roles ?? this.roles,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    lastError: clearLastError ? null : (lastError ?? this.lastError),
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
  ];
}

/// A diver profile's membership of a library; synced across the profile's
/// devices. Carries a location hint, never credentials.
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
  });

  final String id;
  final String diverId;
  final String libraryId;
  final String memberId;
  final String displayName;
  final String libraryName;
  final String backendKind;
  final String locationHint;

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
  }) => SharedLibraryMembership(
    id: id,
    diverId: diverId,
    libraryId: libraryId,
    memberId: memberId,
    displayName: displayName ?? this.displayName,
    libraryName: libraryName ?? this.libraryName,
    backendKind: backendKind ?? this.backendKind,
    locationHint: locationHint ?? this.locationHint,
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
  ];
}

/// File and folder names inside the club prefix.
abstract final class SharedLibraryLayout {
  /// The folder at the top of the storage that holds every library, beside
  /// `submersion-sync` and `submersion-media`.
  static const librariesDir = 'submersion-sites';
  static const manifestFile = 'submersion-shared-library.json';
  static const rolesFile = 'roles.json';
  static const membersDir = 'members';
  static const sitesDir = 'sites';
  static const suggestionsDir = 'suggestions';
  static const formatVersion = 1;

  static String memberFile(String memberId) => '$membersDir/$memberId.json';
  static String siteFile(String siteId) => '$sitesDir/$siteId.json';
  static String suggestionFile(String id) => '$suggestionsDir/$id.json';
}
