import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// Per library site: the field clocks and this device's dirty flag.
class SharedSiteState {
  const SharedSiteState({
    required this.siteId,
    required this.libraryId,
    this.clocks = const {},
    this.remoteModifiedTime,
    this.dirty = false,
    this.deleted = false,
    this.lastEditorMemberId,
    this.lastEditedAtMs,
  });

  final String siteId;
  final String libraryId;
  final Map<String, FieldClock> clocks;
  final String? remoteModifiedTime;
  final bool dirty;
  final bool deleted;
  final String? lastEditorMemberId;
  final int? lastEditedAtMs;

  SharedSiteState copyWith({
    Map<String, FieldClock>? clocks,
    String? remoteModifiedTime,
    bool clearRemoteModifiedTime = false,
    bool? dirty,
    bool? deleted,
    String? lastEditorMemberId,
    int? lastEditedAtMs,
  }) => SharedSiteState(
    siteId: siteId,
    libraryId: libraryId,
    clocks: clocks ?? this.clocks,
    remoteModifiedTime: clearRemoteModifiedTime
        ? null
        : (remoteModifiedTime ?? this.remoteModifiedTime),
    dirty: dirty ?? this.dirty,
    deleted: deleted ?? this.deleted,
    lastEditorMemberId: lastEditorMemberId ?? this.lastEditorMemberId,
    lastEditedAtMs: lastEditedAtMs ?? this.lastEditedAtMs,
  );
}

/// A proposed edit from a reader: outgoing until uploaded, incoming on an
/// owner's device until accepted or dismissed.
class SharedSiteSuggestion {
  const SharedSiteSuggestion({
    required this.id,
    required this.libraryId,
    required this.siteId,
    required this.memberId,
    required this.memberName,
    this.note = '',
    this.fields = const {},
    required this.createdAt,
    required this.direction,
    this.status = 'pending',
    this.remoteModifiedTime,
  });

  static const outgoing = 'outgoing';
  static const incoming = 'incoming';
  static const pending = 'pending';
  static const uploaded = 'uploaded';
  static const withdrawn = 'withdrawn';

  /// Incoming, signed by a member whose key no owner approved yet: kept
  /// out of the inbox, counted for the owner, and taken in on approval.
  static const held = 'held';

  /// An owner accepted or dismissed it while its file could not be
  /// deleted: kept so the next sync neither re-imports nor shows it, and
  /// retries the delete.
  static const resolved = 'resolved';

  /// The local row id. An owner's incoming copy is kept under
  /// [incomingPrefix] plus the folder's id, apart from the outgoing row of
  /// the same suggestion that another profile on this device wrote.
  final String id;

  static const incomingPrefix = 'in:';

  /// The suggestion's id in the library folder.
  String get fileId =>
      id.startsWith(incomingPrefix) ? id.substring(incomingPrefix.length) : id;

  final String libraryId;
  final String siteId;
  final String memberId;
  final String memberName;
  final String note;
  final Map<String, Object?> fields;
  final DateTime createdAt;
  final String direction;
  final String status;
  final String? remoteModifiedTime;

  SharedSiteSuggestion copyWith({String? status, String? remoteModifiedTime}) =>
      SharedSiteSuggestion(
        id: id,
        libraryId: libraryId,
        siteId: siteId,
        memberId: memberId,
        memberName: memberName,
        note: note,
        fields: fields,
        createdAt: createdAt,
        direction: direction,
        status: status ?? this.status,
        remoteModifiedTime: remoteModifiedTime ?? this.remoteModifiedTime,
      );

  /// The wire form written to `suggestions/<id>.json`.
  Map<String, dynamic> toJson() => {
    'id': fileId,
    'siteId': siteId,
    'memberId': memberId,
    'memberName': memberName,
    'note': note,
    'fields': fields,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory SharedSiteSuggestion.fromJson(
    Map<String, dynamic> json, {
    required String libraryId,
    required String direction,
    String? remoteModifiedTime,
  }) {
    final id = json['id'];
    final siteId = json['siteId'];
    if (id is! String || id.isEmpty || siteId is! String || siteId.isEmpty) {
      throw const FormatException('suggestion without an id or siteId');
    }
    final rawFields = json['fields'];
    return SharedSiteSuggestion(
      id: direction == incoming ? '$incomingPrefix$id' : id,
      libraryId: libraryId,
      siteId: siteId,
      memberId: (json['memberId'] as String?) ?? '',
      memberName: (json['memberName'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      fields: rawFields is Map
          ? Map<String, Object?>.from(rawFields)
          : const {},
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      direction: direction,
      remoteModifiedTime: remoteModifiedTime,
    );
  }
}
