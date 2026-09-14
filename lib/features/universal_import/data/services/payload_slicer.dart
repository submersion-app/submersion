import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// One target's share of an expanded payload, with the index maps that
/// translate between its own lists and the full payload's (issue #1893).
///
/// Review selections, duplicate results and the importer's `diveIdByIndex`
/// are all keyed by list index. Every translation between a slice and the
/// full payload goes through these helpers, so there is one place to get it
/// right.
class DiverSlice {
  const DiverSlice({
    required this.targetKey,
    required this.payload,
    required this.globalIndices,
  });

  /// The [DiverTarget.itemKey] of every item in [payload]; null for a
  /// payload that was never expanded (a single-diver import).
  final String? targetKey;

  final ImportPayload payload;

  /// Per entity type, the full-payload index of each slice item, in order.
  final Map<ImportEntityType, List<int>> globalIndices;

  int toGlobal(ImportEntityType type, int local) => globalIndices[type]![local];

  /// The slice index of full-payload [global], or null outside this slice.
  int? localIndexOf(ImportEntityType type, int global) =>
      _positions(type)[global];

  /// The members of [globals] that belong to this slice, as slice indices.
  Set<int> toLocalSet(ImportEntityType type, Iterable<int> globals) {
    final positions = _positions(type);
    return {for (final g in globals) ?positions[g]};
  }

  Map<int, V> toLocalMap<V>(ImportEntityType type, Map<int, V> globals) {
    final positions = _positions(type);
    return {
      for (final entry in globals.entries) ?positions[entry.key]: entry.value,
    };
  }

  Set<int> toGlobalSet(ImportEntityType type, Iterable<int> locals) => {
    for (final l in locals) toGlobal(type, l),
  };

  Map<int, V> toGlobalMap<V>(ImportEntityType type, Map<int, V> locals) => {
    for (final entry in locals.entries) toGlobal(type, entry.key): entry.value,
  };

  Map<int, int> _positions(ImportEntityType type) {
    final indices = globalIndices[type] ?? const <int>[];
    return {for (var i = 0; i < indices.length; i++) indices[i]: i};
  }
}

/// Splits an expanded payload by [DiverTarget.itemKey] (issue #1893).
class PayloadSlicer {
  const PayloadSlicer._();

  /// One slice per target. [firstTargetKey] (the active profile) comes first
  /// when it has items, then targets in the order their first dive appears,
  /// then targets only reference items carry. A payload without target keys
  /// is returned whole as a single untargeted slice.
  static List<DiverSlice> slice(
    ImportPayload payload, {
    String? firstTargetKey,
  }) {
    final targeted = payload.entities.values.any(
      (items) => items.any((item) => item[DiverTarget.itemKey] is String),
    );
    if (!targeted) {
      return [
        DiverSlice(
          targetKey: null,
          payload: payload,
          globalIndices: {
            for (final entry in payload.entities.entries)
              entry.key: [for (var i = 0; i < entry.value.length; i++) i],
          },
        ),
      ];
    }

    final order = <String>[?firstTargetKey];
    void see(Object? key) {
      if (key is String && !order.contains(key)) order.add(key);
    }

    for (final dive in payload.entitiesOf(ImportEntityType.dives)) {
      see(dive[DiverTarget.itemKey]);
    }
    for (final items in payload.entities.values) {
      for (final item in items) {
        see(item[DiverTarget.itemKey]);
      }
    }

    final slices = <DiverSlice>[];
    for (final target in order) {
      final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
      final globalIndices = <ImportEntityType, List<int>>{};
      for (final MapEntry(key: type, value: items)
          in payload.entities.entries) {
        for (var i = 0; i < items.length; i++) {
          if (items[i][DiverTarget.itemKey] != target) continue;
          (entities[type] ??= []).add(items[i]);
          (globalIndices[type] ??= []).add(i);
        }
      }
      if (entities.isEmpty) continue;

      // Media point at dives by index, so they are renumbered against this
      // slice's own dive list.
      final media = entities[ImportEntityType.media];
      if (media != null) {
        final diveIndices = globalIndices[ImportEntityType.dives] ?? const [];
        final localDive = {
          for (var i = 0; i < diveIndices.length; i++) diveIndices[i]: i,
        };
        entities[ImportEntityType.media] = [
          for (final m in media)
            if (m['_diveIndex'] case final int g)
              {...m, '_diveIndex': localDive[g]}
            else
              m,
        ];
      }

      slices.add(
        DiverSlice(
          targetKey: target,
          payload: ImportPayload(
            entities: entities,
            warnings: payload.warnings,
            // The first slice keeps every definition, as a restore expects;
            // the rest take only the ones their own items name.
            metadata: slices.isEmpty
                ? payload.metadata
                : _metadataFor(payload.metadata, entities),
            sourceDivers: payload.sourceDivers,
          ),
          globalIndices: globalIndices,
        ),
      );
    }
    return slices;
  }

  /// [metadata] with its custom dive role and site type definitions cut to
  /// those [entities] reference. The importer creates every definition it is
  /// given under the slice's diver, so an unfiltered copy would give each
  /// profile the whole library's roles and site types (issue #1893).
  static Map<String, dynamic> _metadataFor(
    Map<String, dynamic> metadata,
    Map<ImportEntityType, List<Map<String, dynamic>>> entities,
  ) {
    final roleIds = <Object?>{
      for (final dive in entities[ImportEntityType.dives] ?? const []) ...[
        dive['diverRoleId'],
        if (dive['buddyRoleRefs'] case final List refs)
          for (final r in refs)
            if (r is Map) r['roleId'],
      ],
    };
    final siteTypeIds = <Object?>{
      for (final site in entities[ImportEntityType.sites] ?? const [])
        if (site['siteTypeRefs'] case final List refs) ...refs,
    };

    List<Object?>? keep(String key, Set<Object?> used) {
      final defs = metadata[key];
      if (defs is! List) return null;
      return [
        for (final d in defs)
          if (d is Map && used.contains(d['id'])) d,
      ];
    }

    return {
      ...metadata,
      ImportPayload.customDiveRolesKey: ?keep(
        ImportPayload.customDiveRolesKey,
        roleIds,
      ),
      ImportPayload.customSiteTypesKey: ?keep(
        ImportPayload.customSiteTypesKey,
        siteTypeIds,
      ),
    };
  }
}
