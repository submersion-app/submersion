import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/services/payload_ref_keys.dart';

/// Splits a multi-diver payload across the profiles the Divers step chose
/// (issue #1893).
///
/// Every item of the result carries [DiverTarget.itemKey]. Dives and
/// certifications take their source diver's target. Reference items (sites,
/// buddies, gear, tags and the rest) follow the dives that use them: one copy
/// per target whose dives reference the item, `uddfId` unchanged, which is
/// safe because PayloadSlicer later gives each target a payload of its own.
/// An item that only skipped dives use is dropped; an item no dive uses goes
/// to the primary target.
///
/// Pure: the same source and mapping always give an equal payload, so the
/// wizard re-expands from the parsed payload instead of from an earlier
/// expansion.
class PayloadDiverExpander {
  const PayloadDiverExpander._();

  /// Stand-in target for dives that are not imported.
  static const _droppedKey = '_dropped';

  /// Reference types, in the order they are emitted.
  static const _referenceTypes = [
    ImportEntityType.sites,
    ImportEntityType.trips,
    ImportEntityType.equipment,
    ImportEntityType.equipmentSets,
    ImportEntityType.buddies,
    ImportEntityType.diveCenters,
    ImportEntityType.courses,
    ImportEntityType.tags,
    ImportEntityType.diveTypes,
  ];

  static ImportPayload expand(
    ImportPayload source,
    Map<String, DiverTarget> mapping, {
    required String activeDiverId,
  }) {
    DiverTarget resolve(String? sourceKey) =>
        mapping[sourceKey ?? SourceDiver.unownedKey] ??
        ExistingDiverTarget(activeDiverId);

    final dives = <Map<String, dynamic>>[];
    final dropped = <Map<String, dynamic>>[];
    final newDiveIndex = <int, int>{};
    final diveTargetByUuid = <String, String>{};
    final sourceDives = source.entitiesOf(ImportEntityType.dives);
    for (var i = 0; i < sourceDives.length; i++) {
      final dive = sourceDives[i];
      final target =
          resolve(dive[SourceDiver.mapKey] as String?).targetKey ?? _droppedKey;
      if (dive['sourceUuid'] case final String uuid) {
        diveTargetByUuid[uuid] = target;
      }
      final copy = <String, dynamic>{...dive, DiverTarget.itemKey: target};
      if (target == _droppedKey) {
        dropped.add(copy);
        continue;
      }
      newDiveIndex[i] = dives.length;
      dives.add(copy);
    }

    final used = _RefUsage.of(source, dives);
    final usedByDropped = _RefUsage.of(source, dropped);
    final primary = _primaryTarget(source.sourceDivers, resolve, activeDiverId);

    final out = <ImportEntityType, List<Map<String, dynamic>>>{
      ImportEntityType.dives: dives,
    };
    final equipmentTargets = <String, List<String>>{};
    for (final type in _referenceTypes) {
      final items = <Map<String, dynamic>>[];
      for (final item in source.entitiesOf(type)) {
        final ref = refOf(type, item);
        final List<String> targets;
        if (used.targetsOf(type, ref).isNotEmpty) {
          targets = used.targetsOf(type, ref).toList();
        } else if (usedByDropped.targetsOf(type, ref).isNotEmpty) {
          targets = const [];
        } else {
          targets = [?primary];
        }
        for (final target in targets) {
          items.add(_copyFor(type, item, target, diveTargetByUuid));
        }
        if (type == ImportEntityType.equipment && ref != null) {
          equipmentTargets[ref] = targets;
        }
      }
      out[type] = items;
    }

    out[ImportEntityType.certifications] = [
      for (final cert in source.entitiesOf(ImportEntityType.certifications))
        if (resolve(cert[SourceDiver.mapKey] as String?).targetKey
            case final target?)
          {...cert, DiverTarget.itemKey: target},
    ];

    // A service record rides with every copy of its equipment.
    out[ImportEntityType.serviceRecords] = [
      for (final record in source.entitiesOf(ImportEntityType.serviceRecords))
        for (final target
            in switch (record[serviceRecordRefTypes.keys.single]) {
              final String ref when equipmentTargets.containsKey(ref) =>
                equipmentTargets[ref]!,
              _ => [?primary],
            })
          {...record, DiverTarget.itemKey: target},
    ];

    final media = <Map<String, dynamic>>[];
    for (final item in source.entitiesOf(ImportEntityType.media)) {
      final oldIndex = item['_diveIndex'];
      if (oldIndex is int) {
        final newIndex = newDiveIndex[oldIndex];
        if (newIndex == null) continue;
        media.add({
          ...item,
          '_diveIndex': newIndex,
          DiverTarget.itemKey: dives[newIndex][DiverTarget.itemKey],
        });
      } else if (primary != null) {
        media.add({...item, DiverTarget.itemKey: primary});
      }
    }
    out[ImportEntityType.media] = media;

    _addNameTags(out, source.sourceDivers);

    return ImportPayload(
      entities: {
        for (final entry in out.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      },
      warnings: source.warnings,
      metadata: source.metadata,
      sourceDivers: source.sourceDivers,
    );
  }

  /// The id dives use to reference [item]: the slug for a dive type,
  /// otherwise its `uddfId`, otherwise its name (the importer's fallback).
  static String? refOf(ImportEntityType type, Map<String, dynamic> item) {
    final id = type == ImportEntityType.diveTypes
        ? (item['id'] ?? item['uddfId'])
        : (item['uddfId'] ?? item['name']);
    return id is String && id.isNotEmpty ? id : null;
  }

  /// The target unused items go to: the active profile when any diver maps
  /// to it, otherwise the target of the mapped diver with the most dives.
  static String? _primaryTarget(
    List<SourceDiver> divers,
    DiverTarget Function(String?) resolve,
    String activeDiverId,
  ) {
    final activeKey = ExistingDiverTarget(activeDiverId).targetKey;
    String? best;
    var bestDives = -1;
    for (final diver in divers) {
      final key = resolve(diver.key).targetKey;
      if (key == null) continue;
      if (key == activeKey) return activeKey;
      if (diver.diveCount > bestDives) {
        best = key;
        bestDives = diver.diveCount;
      }
    }
    return best;
  }

  /// [item] stamped for [target]. A gear copy keeps only the check-ins of
  /// its own target's dives, plus any not tied to a dive in this file.
  static Map<String, dynamic> _copyFor(
    ImportEntityType type,
    Map<String, dynamic> item,
    String target,
    Map<String, String> diveTargetByUuid,
  ) {
    final copy = <String, dynamic>{...item, DiverTarget.itemKey: target};
    final observations = item['observations'];
    if (type == ImportEntityType.equipment && observations is List) {
      copy['observations'] = [
        for (final o in observations)
          if (o is! Map ||
              switch (o['diveRef']) {
                final String ref when diveTargetByUuid.containsKey(ref) =>
                  diveTargetByUuid[ref] == target,
                _ => true,
              })
            o,
      ];
    }
    return copy;
  }

  /// When one target takes dives from two or more source divers, tags each
  /// dive with the name it was logged under so the merged profile can still
  /// tell them apart (#912). The unowned row gets no tag.
  static void _addNameTags(
    Map<ImportEntityType, List<Map<String, dynamic>>> out,
    List<SourceDiver> sourceDivers,
  ) {
    String sourceOf(Map<String, dynamic> dive) =>
        dive[SourceDiver.mapKey] as String? ?? SourceDiver.unownedKey;

    final dives = out[ImportEntityType.dives]!;
    final sourcesByTarget = <String, Set<String>>{};
    for (final dive in dives) {
      (sourcesByTarget[dive[DiverTarget.itemKey] as String] ??= {}).add(
        sourceOf(dive),
      );
    }
    final nameByKey = {for (final d in sourceDivers) d.key: d.name.trim()};
    final tags = out[ImportEntityType.tags] ??= [];

    for (final MapEntry(key: target, value: sources)
        in sourcesByTarget.entries) {
      if (sources.length < 2) continue;
      for (final sourceKey in sources) {
        final name = nameByKey[sourceKey] ?? '';
        if (sourceKey == SourceDiver.unownedKey || name.isEmpty) continue;
        final exists = tags.any(
          (t) => t[DiverTarget.itemKey] == target && t['uddfId'] == name,
        );
        if (!exists) {
          tags.add({'name': name, 'uddfId': name, DiverTarget.itemKey: target});
        }
        for (var i = 0; i < dives.length; i++) {
          final dive = dives[i];
          if (dive[DiverTarget.itemKey] != target) continue;
          if (sourceOf(dive) != sourceKey) continue;
          final refs = [...?(dive['tagRefs'] as List?)];
          if (!refs.contains(name)) {
            dives[i] = {
              ...dive,
              'tagRefs': [...refs, name],
            };
          }
        }
      }
    }
  }
}

/// Which targets reference each item, by entity type and reference id.
class _RefUsage {
  _RefUsage._();

  final Map<ImportEntityType, Map<String, Set<String>>> _targets = {};

  /// Usage by [dives] (each stamped with its target), including items only
  /// reached through another item.
  factory _RefUsage.of(ImportPayload source, List<Map<String, dynamic>> dives) {
    final usage = _RefUsage._();
    for (final dive in dives) {
      usage._addDive(dive, dive[DiverTarget.itemKey] as String);
    }
    usage._followLinks(source);
    return usage;
  }

  Set<String> targetsOf(ImportEntityType type, String? ref) =>
      ref == null ? const {} : (_targets[type]?[ref] ?? const {});

  /// Records [target] as a user of [ref]; true when that is new.
  bool _add(ImportEntityType type, Object? ref, String target) {
    if (ref is! String || ref.isEmpty) return false;
    return ((_targets[type] ??= {})[ref] ??= <String>{}).add(target);
  }

  void _addDive(Map<String, dynamic> dive, String target) {
    final site = dive['site'];
    if (site is Map) _add(ImportEntityType.sites, site['uddfId'], target);
    for (final MapEntry(:key, value: type) in diveScalarRefTypes.entries) {
      _add(type, dive[key], target);
    }
    for (final MapEntry(:key, value: type) in diveListRefTypes.entries) {
      final refs = dive[key];
      if (refs is List) {
        for (final ref in refs) {
          _add(type, ref, target);
        }
      }
    }
    _addNested(dive['gearLinks'], gearLinkRefTypes, target);
    _addNested(dive['buddyRoleRefs'], buddyRoleRefTypes, target);
    final typeIds = dive['diveTypeIds'];
    if (typeIds is List) {
      for (final id in typeIds) {
        _add(ImportEntityType.diveTypes, id, target);
      }
    }
    _add(ImportEntityType.diveTypes, dive['diveType'], target);
  }

  void _addNested(
    Object? entries,
    Map<String, ImportEntityType> fields,
    String target,
  ) {
    if (entries is! List) return;
    for (final entry in entries) {
      if (entry is! Map) continue;
      for (final MapEntry(:key, value: type) in fields.entries) {
        _add(type, entry[key], target);
      }
    }
  }

  /// Items reached through another item follow it: an item's components,
  /// parent and tags, a set's items, a course's instructor, a site's tags.
  /// Repeats until nothing new is reached, so chains of any depth are
  /// followed.
  void _followLinks(ImportPayload source) {
    var changed = true;
    while (changed) {
      changed = false;
      void follow(
        ImportEntityType fromType,
        ImportEntityType toType,
        Map<String, dynamic> item,
        List<Object?> linked,
      ) {
        final ref = PayloadDiverExpander.refOf(fromType, item);
        for (final target in targetsOf(fromType, ref).toList()) {
          for (final link in linked) {
            if (_add(toType, link, target)) changed = true;
          }
        }
      }

      for (final item in source.entitiesOf(ImportEntityType.equipment)) {
        final components = item['components'];
        follow(ImportEntityType.equipment, ImportEntityType.equipment, item, [
          item['parentRef'],
          if (components is List)
            for (final c in components)
              if (c is Map) c[componentRefTypes.keys.single],
        ]);
        // An item's own tags follow it (issue #1942), like a site's.
        for (final MapEntry(:key, value: type)
            in equipmentListRefTypes.entries) {
          final refs = item[key];
          follow(ImportEntityType.equipment, type, item, [
            if (refs is List) ...refs,
          ]);
        }
      }
      for (final set in source.entitiesOf(ImportEntityType.equipmentSets)) {
        final refs = set['equipmentRefs'];
        follow(
          ImportEntityType.equipmentSets,
          ImportEntityType.equipment,
          set,
          [if (refs is List) ...refs],
        );
      }
      for (final course in source.entitiesOf(ImportEntityType.courses)) {
        follow(ImportEntityType.courses, ImportEntityType.buddies, course, [
          course['instructorRef'],
        ]);
      }
      for (final site in source.entitiesOf(ImportEntityType.sites)) {
        for (final MapEntry(:key, value: type) in siteListRefTypes.entries) {
          final refs = site[key];
          follow(ImportEntityType.sites, type, site, [
            if (refs is List) ...refs,
          ]);
        }
      }
    }
  }
}
