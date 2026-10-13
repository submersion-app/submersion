import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// One site as stored in `sites/<id>.json` of a shared site library (issue #2567).
///
/// Every value in [fields] is plain JSON: scalars for the site columns and
/// lists for the children (`siteTypes`, `tags`, `species`, `features`).
/// [clocks] names, per field, when it last changed and by which member;
/// [deleted] is clocked under [deletedField]. Keys this build does not know
/// are kept in [extra] and written back, so a newer app's additions survive
/// an older app's upload.
class SiteDocument {
  const SiteDocument({
    required this.id,
    this.deleted = false,
    this.fields = const {},
    this.clocks = const {},
    this.extra = const {},
  });

  final String id;
  final bool deleted;
  final Map<String, Object?> fields;
  final Map<String, FieldClock> clocks;
  final Map<String, Object?> extra;

  static const String deletedField = 'deleted';

  /// Every field a document may carry, in a stable order.
  static const List<String> fieldNames = [
    'name',
    'description',
    'latitude',
    'longitude',
    'minDepth',
    'maxDepth',
    'difficulty',
    'waterType',
    'bodyOfWater',
    'city',
    'island',
    'country',
    'region',
    'hazards',
    'accessNotes',
    'mooringNumber',
    'parkingInfo',
    'altitude',
    'entryMethod',
    'exitMethod',
    'siteTypes',
    'tags',
    'species',
    'features',
  ];

  /// The member's own: kept on the library site row, never uploaded, and
  /// dropped from documents written by older builds (issue #2567).
  static const Set<String> privateFields = {'notes', 'rating'};

  /// The fields that are lists of children rather than a site column.
  static const Set<String> listFields = {
    'siteTypes',
    'tags',
    'species',
    'features',
  };

  static const _knownKeys = {
    'id',
    'formatVersion',
    'deleted',
    'fields',
    'clocks',
  };

  factory SiteDocument.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('site document without an id');
    }
    final clocks = <String, FieldClock>{};
    final rawClocks = json['clocks'];
    if (rawClocks is Map) {
      for (final entry in rawClocks.entries) {
        final value = entry.value;
        if (value is! Map || privateFields.contains(entry.key)) continue;
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
    return SiteDocument(
      id: id,
      deleted: json['deleted'] == true,
      fields: rawFields is Map
          ? {
              for (final e in rawFields.entries)
                if (!privateFields.contains(e.key)) '${e.key}': e.value,
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
    'formatVersion': SharedLibraryLayout.formatVersion,
    'deleted': deleted,
    // Never a member's private fields, nor when they were edited: a state
    // from an older build may still hold their clocks.
    'fields': {
      for (final e in fields.entries)
        if (!privateFields.contains(e.key)) e.key: e.value,
    },
    'clocks': {
      for (final e in clocks.entries)
        if (!privateFields.contains(e.key)) e.key: e.value.toJson(),
    },
  };

  static Uint8List encode(SiteDocument doc) =>
      Uint8List.fromList(utf8.encode(jsonEncode(doc.toJson())));

  static SiteDocument decode(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('site document is not an object');
    }
    return SiteDocument.fromJson(decoded);
  }

  SiteDocument copyWith({
    bool? deleted,
    Map<String, Object?>? fields,
    Map<String, FieldClock>? clocks,
  }) => SiteDocument(
    id: id,
    deleted: deleted ?? this.deleted,
    fields: fields ?? this.fields,
    clocks: clocks ?? this.clocks,
    extra: extra,
  );
}
