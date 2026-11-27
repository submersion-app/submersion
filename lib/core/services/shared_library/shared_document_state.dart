import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// This device's record of one shared library document (issue #4713): its
/// field clocks, whether it waits to be uploaded, and the stamp of the file
/// as last read. The twin of `SharedSiteState`.
class SharedDocumentState {
  const SharedDocumentState({
    required this.documentId,
    required this.libraryId,
    required this.siteId,
    this.clocks = const {},
    this.remoteModifiedTime,
    this.dirty = false,
    this.deleted = false,
    this.parked = false,
    this.lastEditorMemberId,
    this.lastEditedAtMs,
  });

  final String documentId;
  final String libraryId;

  /// The library site the document is filed under; fixed at share time.
  final String siteId;
  final Map<String, FieldClock> clocks;
  final String? remoteModifiedTime;
  final bool dirty;
  final bool deleted;

  /// Read while its site was not in the library: read again when it is.
  final bool parked;
  final String? lastEditorMemberId;
  final int? lastEditedAtMs;

  SharedDocumentState copyWith({
    Map<String, FieldClock>? clocks,
    String? remoteModifiedTime,
    bool clearRemoteModifiedTime = false,
    bool? dirty,
    bool? deleted,
    bool? parked,
    String? lastEditorMemberId,
    int? lastEditedAtMs,
  }) => SharedDocumentState(
    documentId: documentId,
    libraryId: libraryId,
    siteId: siteId,
    clocks: clocks ?? this.clocks,
    remoteModifiedTime: clearRemoteModifiedTime
        ? null
        : (remoteModifiedTime ?? this.remoteModifiedTime),
    dirty: dirty ?? this.dirty,
    deleted: deleted ?? this.deleted,
    parked: parked ?? this.parked,
    lastEditorMemberId: lastEditorMemberId ?? this.lastEditorMemberId,
    lastEditedAtMs: lastEditedAtMs ?? this.lastEditedAtMs,
  );
}
