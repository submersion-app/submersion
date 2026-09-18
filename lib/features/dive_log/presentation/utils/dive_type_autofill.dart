import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

/// The dive form's dive types after a site assignment, plus which of them the
/// site put there, so the next assignment knows what it may take back.
class DiveTypeSelection {
  const DiveTypeSelection({required this.typeIds, required this.siteAddedIds});

  final List<String> typeIds;

  /// The subset of [typeIds] the assigned site added and the diver has not
  /// touched since.
  final Set<String> siteAddedIds;
}

/// The ids of the [diveTypes] that [siteTypes] stand for, in dive type order
/// (issue #2037).
///
/// Site types (reef, wreck, cenote, ...) and dive types (recreational, wreck,
/// night, ...) are separate vocabularies. A site type stands for a dive type
/// when the two share a slug: the built-ins wreck, cave and cavern, or a
/// custom type the diver named the same on both sides. The id alone cannot
/// match custom types, because a custom site type's id always carries a
/// random suffix, so the names are compared too.
List<String> diveTypeIdsForSiteTypes({
  required List<SiteTypeEntity> siteTypes,
  required List<DiveTypeEntity> diveTypes,
}) {
  if (siteTypes.isEmpty) return const [];
  final siteKeys = {
    for (final t in siteTypes) ...[t.id, DiveTypeEntity.generateSlug(t.name)],
  };
  return [
    for (final t in diveTypes)
      if (siteKeys.contains(t.id) ||
          siteKeys.contains(DiveTypeEntity.generateSlug(t.name)))
        t.id,
  ];
}

/// The dive's types after a site standing for [siteDiveTypeIds] is assigned
/// (an empty list when the site is cleared or has no matching types).
///
/// Snap-on-assign, additive, with one way back: a type the previous site
/// added ([previousSiteAddedIds]) is taken off again unless the new site
/// stands for it too. A type the dive already had is never removed and never
/// claimed as site-added, so the diver's own choices survive every change of
/// site.
DiveTypeSelection diveTypesAfterSiteAssign({
  required List<String> currentTypeIds,
  required Set<String> previousSiteAddedIds,
  required List<String> siteDiveTypeIds,
}) {
  final siteIds = siteDiveTypeIds.toSet();
  final kept = [
    for (final id in currentTypeIds)
      if (!previousSiteAddedIds.contains(id) || siteIds.contains(id)) id,
  ];
  final keptIds = kept.toSet();
  final added = [
    for (final id in siteDiveTypeIds)
      if (!keptIds.contains(id)) id,
  ];
  // A dive always has at least one type. When taking back would leave none
  // (the diver unticked everything the site did not add), what the site
  // added stays, as the diver's own.
  if (kept.isEmpty && added.isEmpty && currentTypeIds.isNotEmpty) {
    return DiveTypeSelection(typeIds: currentTypeIds, siteAddedIds: const {});
  }
  return DiveTypeSelection(
    typeIds: [...kept, ...added],
    siteAddedIds: {
      for (final id in kept)
        if (previousSiteAddedIds.contains(id)) id,
      ...added,
    },
  );
}

/// What stays site-added after the diver sets the dive types to
/// [selectedTypeIds] by hand. A site-added type the diver unticks is theirs
/// from then on, even if they tick it again.
Set<String> siteAddedAfterManualEdit({
  required Set<String> siteAddedIds,
  required List<String> selectedTypeIds,
}) => siteAddedIds.intersection(selectedTypeIds.toSet());
