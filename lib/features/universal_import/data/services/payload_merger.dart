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

  ImportPayload merge(List<FilePayload> inputs) {
    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    final warnings = <ImportWarning>[];
    // prefixed folded id -> prefixed survivor id
    final aliases = <String, String>{};
    // entity type -> fold key -> surviving map (already in `entities`)
    final survivors = <ImportEntityType, Map<String, Map<String, dynamic>>>{};

    for (final input in inputs) {
      warnings.addAll(input.payload.warnings);

      // Dives are appended without folding, so each file's dive indices shift
      // by the number of dives already collected. Captured BEFORE this input's
      // dives are added, so media can rebase onto the merged dive list.
      final diveOffset = (entities[ImportEntityType.dives] ?? const []).length;

      for (final type in ImportEntityType.values) {
        final items = input.payload.entitiesOf(type);
        if (items.isEmpty) continue;

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

          final key = _foldKey(type, item);
          if (key == null) {
            (entities[type] ??= []).add(item);
            continue;
          }

          final byKey = survivors[type] ??= {};
          final survivor = byKey[key];
          if (survivor == null) {
            byKey[key] = item;
            (entities[type] ??= []).add(item);
          } else {
            // Enrich the survivor with fields it is missing.
            for (final entry in item.entries) {
              if (entry.key == 'uddfId' ||
                  entry.key == '_sourceFile' ||
                  entry.key == '_sourceFileId') {
                continue;
              }
              final existing = survivor[entry.key];
              if (existing == null ||
                  (existing is String && existing.isEmpty)) {
                if (entry.value != null) survivor[entry.key] = entry.value;
              }
            }
            final foldedId = item['uddfId'] as String?;
            final survivorId = survivor['uddfId'] as String?;
            if (foldedId != null && survivorId != null) {
              aliases[foldedId] = survivorId;
            }
          }
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
