import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// One parsed file's payload plus its batch identity.
class FilePayload {
  final String fileId; // stable per-file prefix key, e.g. 'f0'
  final String fileName; // display name, stamped as `_sourceFile`
  final ImportPayload payload;

  const FilePayload({
    required this.fileId,
    required this.fileName,
    required this.payload,
  });
}

/// A reference record that survived folding, known by the source id of
/// every record folded into it (issue #1807).
class _Survivor {
  _Survivor(this.item, String? sourceId) {
    if (sourceId != null) sourceIds.add(sourceId);
  }

  final Map<String, dynamic> item;
  final Set<String> sourceIds = {};
}

/// Merges N per-file [ImportPayload]s into one batch payload.
///
/// - Every `uddfId` (and dive-side reference to one) is prefixed with the
///   file's id (`f0:site_1`) so IDs from different files cannot collide.
/// - Reference entities (sites, buddies, trips, dive centers, tags, dive
///   types, courses, equipment sets by normalized name; equipment by
///   name+type; certifications by name+agency) are folded across files:
///   the first occurrence survives, enriched with later files' non-null
///   fields, and dive-side references to folded entities are rewritten to
///   the survivor's id.
/// - Records within one file are already distinct by id, so they never fold
///   into each other; only repeats of one id do (issue #1807). Across files,
///   a name held by one record on each side folds; when either side holds
///   several, records pair only by a shared source id and the rest stay
///   apart rather than merging two namesakes on a guess.
/// - Dives are NEVER folded; cross-file dive duplicates are left for the
///   duplicate checker so the user decides.
class PayloadMerger {
  const PayloadMerger();

  /// Dive map fields holding a single entity reference.
  static const _scalarRefFields = [
    'siteId',
    'tripRef',
    'diveCenterRef',
    'courseRef',
  ];

  /// Dive map fields holding a list of entity references.
  static const _listRefFields = [
    'equipmentRefs',
    'buddyRefs',
    'diveGuideRefs',
    'tagRefs',
  ];

  /// Reference fields inside a dive's `gearLinks` entries and an item's
  /// `components` entries (issue #1487): nested lists of maps, so they
  /// need their own pass.
  static const _gearLinkRefFields = ['itemRef', 'viaRef', 'setRef'];
  static const _componentRefFields = ['componentRef'];

  /// Reference field inside a dive's `buddyRoleRefs` entries (issue #1737):
  /// the person holding each exact role.
  static const _buddyRoleRefFields = ['buddyRef'];

  /// Rewrites the string reference [fields] of every map in [item]'s
  /// [key] list through [rewrite], copying rather than mutating the
  /// nested maps. A null reference stays null; a map without the list is
  /// left without it.
  ///
  /// Matches a bare [Map] rather than `Map<String, dynamic>`: parsers hand
  /// these lists over with whatever type argument the literal inferred
  /// (`Map<String, String?>` from the gear-link parser today), and a map
  /// that failed the narrower check would be passed through with its refs
  /// un-namespaced, which merges two files' rows together instead of
  /// failing loudly. Entries are re-keyed to `Map<String, dynamic>` so the
  /// list is uniform whatever arrived.
  static void _rewriteNested(
    Map<String, dynamic> item,
    String key,
    List<String> fields,
    String Function(String ref) rewrite,
  ) {
    final value = item[key];
    if (value is! List) return;
    item[key] = [
      for (final entry in value)
        if (entry is Map)
          <String, dynamic>{
            for (final pair in entry.entries) '${pair.key}': pair.value,
            for (final field in fields)
              if (entry[field] case final String ref when ref.isNotEmpty)
                field: rewrite(ref),
          }
        else
          entry,
    ];
  }

  ImportPayload merge(List<FilePayload> inputs) {
    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    final warnings = <ImportWarning>[];
    // prefixed folded id -> prefixed survivor id
    final aliases = <String, String>{};
    // entity type -> fold key -> surviving records (already in `entities`),
    // in first-seen order
    final survivors = <ImportEntityType, Map<String, List<_Survivor>>>{};
    // Custom dive role definitions by id (issue #1737). Ids are device-minted
    // UUIDs referenced verbatim by dive links, so they are never namespaced,
    // and the same id in two files is the same role.
    final customDiveRoles = <String, Map<String, dynamic>>{};

    for (final input in inputs) {
      warnings.addAll(input.payload.warnings);
      final roles = input.payload.metadata[ImportPayload.customDiveRolesKey];
      for (final role in roles is List ? roles : const []) {
        if (role is Map<String, dynamic> && role['id'] is String) {
          customDiveRoles.putIfAbsent(role['id'] as String, () => role);
        }
      }

      // Dives are appended without folding, so each file's dive indices shift
      // by the number of dives already collected. Captured BEFORE this input's
      // dives are added, so media can rebase onto the merged dive list.
      final diveOffset = (entities[ImportEntityType.dives] ?? const []).length;

      for (final type in ImportEntityType.values) {
        final items = input.payload.entitiesOf(type);
        if (items.isEmpty) continue;

        final references = <Map<String, dynamic>>[];
        for (final original in items) {
          final item = _namespaced(original, input.fileId, type);
          item['_sourceFile'] = input.fileName;
          // Display names can collide (same basename in different folders);
          // the id is the collision-free key for per-file attribution.
          item['_sourceFileId'] = input.fileId;

          // Two pictures of the same file are both real, so media never
          // folds. Its dive pointer is rebased onto the merged dive list.
          if (type == ImportEntityType.media) {
            final index = item['_diveIndex'];
            if (index is int) item['_diveIndex'] = index + diveOffset;
            (entities[type] ??= []).add(item);
            continue;
          }

          if (type == ImportEntityType.dives) {
            (entities[type] ??= []).add(item);
            continue;
          }

          references.add(item);
        }

        if (references.isNotEmpty) {
          _foldFileReferences(
            type: type,
            fileId: input.fileId,
            items: references,
            survivors: survivors[type] ??= {},
            out: entities[type] ??= [],
            aliases: aliases,
          );
        }
      }
    }

    _rewriteAliases(entities, aliases);

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {
        'batchFileCount': inputs.length,
        'sourceFiles': [for (final i in inputs) i.fileName],
        if (customDiveRoles.isNotEmpty)
          ImportPayload.customDiveRolesKey: customDiveRoles.values.toList(),
      },
    );
  }

  /// Deep-copy [original] with all uddfId-style references prefixed.
  Map<String, dynamic> _namespaced(
    Map<String, dynamic> original,
    String fileId,
    ImportEntityType type,
  ) {
    final item = Map<String, dynamic>.of(original);

    // Dive types use a semantic slug in 'id', shared across files by design.
    if (type != ImportEntityType.diveTypes) {
      final uddfId = item['uddfId'];
      if (uddfId is String && uddfId.isNotEmpty) {
        item['uddfId'] = '$fileId:$uddfId';
      }
    }

    if (type == ImportEntityType.dives) {
      final site = item['site'];
      if (site is Map<String, dynamic>) {
        final copy = Map<String, dynamic>.of(site);
        final siteId = copy['uddfId'];
        if (siteId is String && siteId.isNotEmpty) {
          copy['uddfId'] = '$fileId:$siteId';
        }
        item['site'] = copy;
      }
      for (final field in _scalarRefFields) {
        final value = item[field];
        if (value is String && value.isNotEmpty) {
          item[field] = '$fileId:$value';
        }
      }
      for (final field in _listRefFields) {
        final value = item[field];
        if (value is List) {
          item[field] = [
            for (final ref in value)
              if (ref is String && ref.isNotEmpty) '$fileId:$ref' else ref,
          ];
        }
      }
      _rewriteNested(
        item,
        'gearLinks',
        _gearLinkRefFields,
        (ref) => '$fileId:$ref',
      );
      _rewriteNested(
        item,
        'buddyRoleRefs',
        _buddyRoleRefFields,
        (ref) => '$fileId:$ref',
      );
    }

    if (type == ImportEntityType.equipment) {
      _rewriteNested(
        item,
        'components',
        _componentRefFields,
        (ref) => '$fileId:$ref',
      );
    }

    if (type == ImportEntityType.equipmentSets) {
      final refs = item['equipmentRefs'];
      if (refs is List) {
        item['equipmentRefs'] = [
          for (final ref in refs)
            if (ref is String && ref.isNotEmpty) '$fileId:$ref' else ref,
        ];
      }
    }

    return item;
  }

  /// Folds one file's reference records of one [type] into the batch.
  ///
  /// A named record the file repeats under one id is one record, so the
  /// repeats fold into its first occurrence. Records with different ids stay
  /// distinct (issue #1807), and each earlier-file [survivors] entry takes
  /// at most one of them: by name when the name is held by exactly one
  /// record on each side, otherwise only by a shared source id. A record
  /// with no match is added to [out] and, if named, becomes a survivor for
  /// later files.
  void _foldFileReferences({
    required ImportEntityType type,
    required String fileId,
    required List<Map<String, dynamic>> items,
    required Map<String, List<_Survivor>> survivors,
    required List<Map<String, dynamic>> out,
    required Map<String, String> aliases,
  }) {
    final records = <({Map<String, dynamic> item, String? key})>[];
    final firstById = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final key = _foldKey(type, item);
      final id = _recordId(type, item);
      if (key != null && id != null) {
        final first = firstById[id];
        if (first != null) {
          _enrich(first, item);
          continue;
        }
        firstById[id] = item;
      }
      records.add((item: item, key: key));
    }

    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final (:item, :key) in records) {
      if (key != null) (byKey[key] ??= []).add(item);
    }

    final matches = Map<Map<String, dynamic>, _Survivor>.identity();
    for (final MapEntry(:key, value: group) in byKey.entries) {
      final candidates = [...?survivors[key]];
      if (group.length == 1 && candidates.length == 1) {
        matches[group.single] = candidates.single;
        continue;
      }
      for (final item in group) {
        final sourceId = _sourceId(type, item, fileId);
        if (sourceId == null) continue;
        final index = candidates.indexWhere(
          (s) => s.sourceIds.contains(sourceId),
        );
        if (index >= 0) matches[item] = candidates.removeAt(index);
      }
    }

    for (final (:item, :key) in records) {
      final sourceId = _sourceId(type, item, fileId);
      final survivor = matches[item];
      if (survivor == null) {
        out.add(item);
        if (key != null) (survivors[key] ??= []).add(_Survivor(item, sourceId));
        continue;
      }
      _enrich(survivor.item, item);
      if (sourceId != null) survivor.sourceIds.add(sourceId);
      final foldedId = item['uddfId'];
      final survivorId = survivor.item['uddfId'];
      if (foldedId is String && survivorId is String) {
        aliases[foldedId] = survivorId;
      }
    }
  }

  /// Fills [survivor]'s missing or empty fields from [item], leaving its
  /// identity and file attribution alone.
  static void _enrich(
    Map<String, dynamic> survivor,
    Map<String, dynamic> item,
  ) {
    for (final entry in item.entries) {
      if (entry.key == 'uddfId' ||
          entry.key == '_sourceFile' ||
          entry.key == '_sourceFileId') {
        continue;
      }
      final existing = survivor[entry.key];
      if (existing == null || (existing is String && existing.isEmpty)) {
        if (entry.value != null) survivor[entry.key] = entry.value;
      }
    }
  }

  /// [item]'s id within the batch. Dive types without a `uddfId` are
  /// identified by the slug in `id`, which is shared across files.
  static String? _recordId(ImportEntityType type, Map<String, dynamic> item) {
    final id =
        item['uddfId'] ??
        (type == ImportEntityType.diveTypes ? item['id'] : null);
    return id is String && id.isNotEmpty ? id : null;
  }

  /// [item]'s id as its source file wrote it, without the batch prefix.
  /// Dive types are never prefixed, so theirs comes back unchanged.
  static String? _sourceId(
    ImportEntityType type,
    Map<String, dynamic> item,
    String fileId,
  ) {
    final id = _recordId(type, item);
    if (id == null) return null;
    final prefix = '$fileId:';
    return id.startsWith(prefix) ? id.substring(prefix.length) : id;
  }

  /// Cross-file fold key for reference entities; null means "never fold".
  String? _foldKey(ImportEntityType type, Map<String, dynamic> item) {
    final name = (item['name'] as String?)?.trim().toLowerCase();
    if (name == null || name.isEmpty) return null;

    switch (type) {
      case ImportEntityType.equipment:
        final typeValue = item['type'];
        final typeStr = typeValue is String
            ? typeValue.toLowerCase()
            : typeValue?.toString().toLowerCase() ?? 'other';
        return '$name|$typeStr';
      case ImportEntityType.certifications:
        final agency = item['agency'];
        final agencyStr = agency is String
            ? agency.toLowerCase()
            : agency?.toString().toLowerCase() ?? '';
        return '$name|$agencyStr';
      case ImportEntityType.dives:
      // Service records are events, not named entities: two services on the
      // same item are both real and must never fold together.
      case ImportEntityType.serviceRecords:
      // Media is handled before this point and has no name to fold on.
      case ImportEntityType.media:
        return null;
      case ImportEntityType.sites:
      case ImportEntityType.trips:
      case ImportEntityType.buddies:
      case ImportEntityType.diveCenters:
      case ImportEntityType.tags:
      case ImportEntityType.diveTypes:
      case ImportEntityType.courses:
      case ImportEntityType.equipmentSets:
        return name;
    }
  }

  void _rewriteAliases(
    Map<ImportEntityType, List<Map<String, dynamic>>> entities,
    Map<String, String> aliases,
  ) {
    if (aliases.isEmpty) return;

    String resolve(String id) => aliases[id] ?? id;

    for (final dive in entities[ImportEntityType.dives] ?? const []) {
      final site = dive['site'];
      if (site is Map<String, dynamic>) {
        final siteId = site['uddfId'];
        if (siteId is String) site['uddfId'] = resolve(siteId);
      }
      for (final field in _scalarRefFields) {
        final value = dive[field];
        if (value is String) dive[field] = resolve(value);
      }
      for (final field in _listRefFields) {
        final value = dive[field];
        if (value is List) {
          dive[field] = [
            for (final ref in value)
              if (ref is String) resolve(ref) else ref,
          ];
        }
      }
      _rewriteNested(dive, 'gearLinks', _gearLinkRefFields, resolve);
      _rewriteNested(dive, 'buddyRoleRefs', _buddyRoleRefFields, resolve);
    }

    for (final item in entities[ImportEntityType.equipment] ?? const []) {
      _rewriteNested(item, 'components', _componentRefFields, resolve);
    }

    for (final set in entities[ImportEntityType.equipmentSets] ?? const []) {
      final refs = set['equipmentRefs'];
      if (refs is List) {
        set['equipmentRefs'] = [
          for (final ref in refs)
            if (ref is String) resolve(ref) else ref,
        ];
      }
    }
  }
}
