import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/services/diver_slice_duplicates.dart';
import 'package:submersion/features/universal_import/data/services/payload_slicer.dart';

/// One [DiverSlice]'s share of the review, in the slice's own indices
/// (issue #1893): what the importer needs to run the slice as if it were a
/// whole import.
class DiverSliceReview {
  const DiverSliceReview({
    required this.bundle,
    required this.selections,
    required this.duplicateActions,
  });

  final ImportBundle bundle;
  final Map<ImportEntityType, Set<int>> selections;
  final Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions;

  factory DiverSliceReview.of(
    DiverSlice slice,
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions,
  ) {
    return DiverSliceReview(
      bundle: ImportBundle(
        source: bundle.source,
        groups: {
          for (final MapEntry(key: type, value: group) in bundle.groups.entries)
            type: _sliceGroup(slice, _uiType(type), group),
        },
        nextDiveNumberByTarget: bundle.nextDiveNumberByTarget,
      ),
      selections: {
        for (final MapEntry(key: type, value: indices) in selections.entries)
          type: slice.toLocalSet(_uiType(type), indices),
      },
      duplicateActions: {
        for (final MapEntry(key: type, value: actions)
            in duplicateActions.entries)
          type: slice.toLocalMap(_uiType(type), actions),
      },
    );
  }

  /// The payload's type of the same name; the wizard's enum is a subset.
  static ui.ImportEntityType _uiType(ImportEntityType type) =>
      ui.ImportEntityType.values.byName(type.name);

  static EntityGroup _sliceGroup(
    DiverSlice slice,
    ui.ImportEntityType type,
    EntityGroup group,
  ) {
    final globals = slice.globalIndices[type] ?? const <int>[];
    final matches = group.matchResults;
    final entityMatches = group.entityMatches;
    final autoSkip = group.autoSkipIndices;
    return EntityGroup(
      items: [for (final g in globals) group.items[g]],
      duplicateIndices: slice.toLocalSet(type, group.duplicateIndices),
      matchResults: matches == null
          ? null
          : {
              for (final entry in slice.toLocalMap(type, matches).entries)
                entry.key: withInBatchIndex(
                  entry.value,
                  switch (entry.value.inBatchIndex) {
                    final int i => slice.localIndexOf(type, i),
                    null => null,
                  },
                ),
            },
      entityMatches: entityMatches == null
          ? null
          : slice.toLocalMap(type, entityMatches),
      autoSkipIndices: autoSkip == null
          ? null
          : slice.toLocalSet(type, autoSkip),
    );
  }
}

/// [total] plus one slice's [result], with the slice's dive indices moved
/// back onto the full payload so the steps after the import (consolidation,
/// photos, per-file outcomes) run unchanged.
UddfEntityImportResult addSliceResult(
  UddfEntityImportResult total,
  DiverSlice slice,
  UddfEntityImportResult result,
) {
  return UddfEntityImportResult(
    trips: total.trips + result.trips,
    equipment: total.equipment + result.equipment,
    equipmentSets: total.equipmentSets + result.equipmentSets,
    buddies: total.buddies + result.buddies,
    diveCenters: total.diveCenters + result.diveCenters,
    certifications: total.certifications + result.certifications,
    tags: total.tags + result.tags,
    diveTypes: total.diveTypes + result.diveTypes,
    sites: total.sites + result.sites,
    dives: total.dives + result.dives,
    courses: total.courses + result.courses,
    diveIds: [...total.diveIds, ...result.diveIds],
    diveIdByIndex: {
      ...total.diveIdByIndex,
      ...slice.toGlobalMap(ui.ImportEntityType.dives, result.diveIdByIndex),
    },
    restoredDataSources: total.restoredDataSources + result.restoredDataSources,
  );
}
