import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Wording for what deleting or merging tags touches (#1902, #1942).
//
// A tag can be scoped to any mix of dives, sites and equipment, and deleting
// or merging it rewrites every item that carries it. Each message names only
// what is actually affected. Every combination is one whole ICU message
// rather than phrases joined here, so every locale controls its own word
// order and list punctuation.

/// [usage] as three counts. A scope missing from the map counts zero.
({int dives, int sites, int equipment}) _counts(Map<TagScope, int> usage) => (
  dives: usage[TagScope.dives] ?? 0,
  sites: usage[TagScope.sites] ?? 0,
  equipment: usage[TagScope.equipment] ?? 0,
);

/// The confirmation for deleting one tag.
String tagDeleteMessage(
  AppLocalizations l10n,
  String tagName,
  Map<TagScope, int> usage,
) {
  final (:dives, :sites, :equipment) = _counts(usage);
  return switch ((dives > 0, sites > 0, equipment > 0)) {
    (true, false, false) => l10n.tags_manage_deleteMessage(tagName, dives),
    (false, true, false) => l10n.tags_manage_deleteMessage_sites(
      tagName,
      sites,
    ),
    (false, false, true) => l10n.tags_manage_deleteMessage_equipment(
      tagName,
      equipment,
    ),
    (true, true, false) => l10n.tags_manage_deleteMessage_divesAndSites(
      tagName,
      dives,
      sites,
    ),
    (true, false, true) => l10n.tags_manage_deleteMessage_divesAndEquipment(
      tagName,
      dives,
      equipment,
    ),
    (false, true, true) => l10n.tags_manage_deleteMessage_sitesAndEquipment(
      tagName,
      sites,
      equipment,
    ),
    (true, true, true) => l10n.tags_manage_deleteMessage_all(
      tagName,
      dives,
      sites,
      equipment,
    ),
    (false, false, false) => l10n.tags_manage_deleteMessage_unused(tagName),
  };
}

/// The confirmation for deleting several tags. [usage] is the union across
/// the selection, so an item carrying two of them counts once.
String tagsBulkDeleteMessage(AppLocalizations l10n, Map<TagScope, int> usage) {
  final (:dives, :sites, :equipment) = _counts(usage);
  return switch ((dives > 0, sites > 0, equipment > 0)) {
    (true, false, false) => l10n.tags_manage_bulkDeleteMessage(dives),
    (false, true, false) => l10n.tags_manage_bulkDeleteMessage_sites(sites),
    (false, false, true) => l10n.tags_manage_bulkDeleteMessage_equipment(
      equipment,
    ),
    (true, true, false) => l10n.tags_manage_bulkDeleteMessage_divesAndSites(
      dives,
      sites,
    ),
    (true, false, true) => l10n.tags_manage_bulkDeleteMessage_divesAndEquipment(
      dives,
      equipment,
    ),
    (false, true, true) => l10n.tags_manage_bulkDeleteMessage_sitesAndEquipment(
      sites,
      equipment,
    ),
    (true, true, true) => l10n.tags_manage_bulkDeleteMessage_all(
      dives,
      sites,
      equipment,
    ),
    (false, false, false) => l10n.tags_manage_bulkDeleteMessage_unused,
  };
}

/// The merge sheet's preview of what a merge rewrites, counted as a union
/// like [tagsBulkDeleteMessage].
String tagsMergeAffectedMessage(
  AppLocalizations l10n,
  Map<TagScope, int> usage,
) {
  final (:dives, :sites, :equipment) = _counts(usage);
  return switch ((dives > 0, sites > 0, equipment > 0)) {
    (true, false, false) => l10n.tags_manage_mergeAffectedDives(dives),
    (false, true, false) => l10n.tags_manage_mergeAffected_sites(sites),
    (false, false, true) => l10n.tags_manage_mergeAffected_equipment(equipment),
    (true, true, false) => l10n.tags_manage_mergeAffected_divesAndSites(
      dives,
      sites,
    ),
    (true, false, true) => l10n.tags_manage_mergeAffected_divesAndEquipment(
      dives,
      equipment,
    ),
    (false, true, true) => l10n.tags_manage_mergeAffected_sitesAndEquipment(
      sites,
      equipment,
    ),
    (true, true, true) => l10n.tags_manage_mergeAffected_all(
      dives,
      sites,
      equipment,
    ),
    (false, false, false) => l10n.tags_manage_mergeAffected_unused,
  };
}

/// One tag's usage as a row subtitle: its dives always, then its sites and
/// equipment items when any carry it, in registry order ("12 dives, 3 sites,
/// 5 equipment items"). Shared by the Manage Tags list and the merge sheet.
String tagUsageCounts(AppLocalizations l10n, Map<TagScope, int> usage) => [
  for (final scope in TagScope.values)
    if (scope == TagScope.dives || (usage[scope] ?? 0) > 0)
      tagScopeCount(l10n, scope, usage[scope] ?? 0),
].join(', ');
