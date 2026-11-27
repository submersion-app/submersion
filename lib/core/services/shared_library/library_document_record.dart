import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/shared_library/clocked_record.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';

/// One document shared with a shared site library, as stored in
/// `documents/document-<id>.json` (issue #4713). Fields merge one by one
/// like a [SiteDocument]'s; [siteId] names the library site it is filed
/// under and never changes, so it is not a clocked field. The page bytes
/// live in `pages/<fileId>.bin`, named by each page in `pages`.
class LibraryDocumentRecord extends ClockedRecord {
  const LibraryDocumentRecord({
    required this.id,
    required this.siteId,
    this.deleted = false,
    this.fields = const {},
    this.clocks = const {},
    this.extra = const {},
  });

  @override
  final String id;
  final String siteId;
  @override
  final bool deleted;
  @override
  final Map<String, Object?> fields;
  @override
  final Map<String, FieldClock> clocks;
  @override
  final Map<String, Object?> extra;

  /// What a document field signature starts with: never a site's, so a
  /// site field signature cannot be replayed onto a document.
  static const String signatureTag = 'ssl-doc-field:v1';

  @override
  String get signatureDomain => signatureTag;

  static const String deletedField = ClockedRecord.deletedField;

  /// Every field a document may carry, in a stable order.
  static const List<String> fieldNames = [
    'type',
    'title',
    'issuer',
    'referenceNumber',
    'issueDate',
    'expiryDate',
    'notes',
    'tags',
    'pages',
  ];

  /// The fields that are lists, each merged as one unit.
  static const Set<String> listFields = {'tags', 'pages'};

  /// A member's own, or meaningless in a library: dropped on read and
  /// never written, whatever an older or newer build put there.
  static const Set<String> neverTravels = {
    'diverId',
    'reminderLeadDays',
    'emergencyPhone',
    'phone',
    'isPrimary',
    'createdAt',
    'updatedAt',
    'hlc',
  };

  static const _knownKeys = {
    'id',
    'siteId',
    'formatVersion',
    'deleted',
    'fields',
    'clocks',
  };

  factory LibraryDocumentRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('library document without an id');
    }
    final siteId = json['siteId'];
    if (siteId is! String || siteId.isEmpty) {
      throw const FormatException('library document without a site');
    }
    final clocks = <String, FieldClock>{};
    final rawClocks = json['clocks'];
    if (rawClocks is Map) {
      for (final entry in rawClocks.entries) {
        final value = entry.value;
        if (value is! Map || neverTravels.contains(entry.key)) continue;
        try {
          clocks[entry.key as String] = FieldClock.fromJson(
            value.cast<String, dynamic>(),
          );
        } on FormatException {
          // An unreadable clock counts as absent: oldest on merge.
        } on TypeError {
          // Same for a clock whose shape this build does not know.
        }
      }
    }
    final rawFields = json['fields'];
    return LibraryDocumentRecord(
      id: id,
      siteId: siteId,
      deleted: json['deleted'] == true,
      fields: rawFields is Map
          ? {
              for (final e in rawFields.entries)
                if (!neverTravels.contains(e.key)) '${e.key}': e.value,
            }
          : const {},
      clocks: clocks,
      extra: {
        for (final entry in json.entries)
          if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    ...extra,
    'id': id,
    'siteId': siteId,
    'formatVersion': SharedLibraryLayout.formatVersion,
    'deleted': deleted,
    'fields': {
      for (final e in fields.entries)
        if (!neverTravels.contains(e.key)) e.key: e.value,
    },
    'clocks': {
      for (final e in clocks.entries)
        if (!neverTravels.contains(e.key)) e.key: e.value.toJson(),
    },
  };

  static Uint8List encode(LibraryDocumentRecord doc) =>
      Uint8List.fromList(utf8.encode(jsonEncode(doc.toJson())));

  static LibraryDocumentRecord decode(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('library document is not an object');
    }
    return LibraryDocumentRecord.fromJson(decoded);
  }

  /// The page list this record names, without the entries it cannot use.
  List<LibraryPageRef> get pageRefs => LibraryPageRef.listFrom(fields['pages']);

  @override
  LibraryDocumentRecord withContent({
    required bool deleted,
    required Map<String, Object?> fields,
    required Map<String, FieldClock> clocks,
    required Map<String, Object?> extra,
  }) => LibraryDocumentRecord(
    id: id,
    siteId: siteId,
    deleted: deleted,
    fields: fields,
    clocks: clocks,
    extra: extra,
  );

  LibraryDocumentRecord copyWith({
    bool? deleted,
    Map<String, Object?>? fields,
    Map<String, FieldClock>? clocks,
  }) => withContent(
    deleted: deleted ?? this.deleted,
    fields: fields ?? this.fields,
    clocks: clocks ?? this.clocks,
    extra: extra,
  );
}

/// One page of a shared document, as named in its `pages` field: where its
/// bytes are stored (`pages/<fileId>.bin`) and their SHA-256, which the
/// signed field carries so a page file cannot be swapped.
class LibraryPageRef {
  const LibraryPageRef({
    required this.id,
    required this.pageIndex,
    this.side,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.fileId,
    required this.sha256,
  });

  final String id;
  final int pageIndex;
  final String? side;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String fileId;
  final String sha256;

  /// The ref [raw] describes, or null when it is not one this build can
  /// use (a missing field, or a file id that could leave the pages folder).
  static LibraryPageRef? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final pageIndex = raw['pageIndex'];
    final side = raw['side'];
    final fileName = raw['fileName'];
    final mimeType = raw['mimeType'];
    final sizeBytes = raw['sizeBytes'];
    final fileId = raw['fileId'];
    final sha = raw['sha256'];
    if (id is! String ||
        pageIndex is! int ||
        (side != null && side is! String) ||
        fileName is! String ||
        mimeType is! String ||
        sizeBytes is! int ||
        fileId is! String ||
        sha is! String ||
        !SharedLibraryTransport.isSafeFileId(fileId)) {
      return null;
    }
    return LibraryPageRef(
      id: id,
      pageIndex: pageIndex,
      side: side as String?,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      fileId: fileId,
      sha256: sha,
    );
  }

  /// Every usable ref in [raw], in order; anything else is skipped.
  static List<LibraryPageRef> listFrom(Object? raw) => [
    if (raw is List)
      for (final entry in raw) ?tryParse(entry),
  ];

  Map<String, Object?> toJson() => {
    'id': id,
    'pageIndex': pageIndex,
    'side': side,
    'fileName': fileName,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'fileId': fileId,
    'sha256': sha256,
  };
}
