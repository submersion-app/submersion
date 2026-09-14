import 'package:submersion/l10n/arb/app_localizations.dart';

// Wording for what deleting or merging tags touches (#1902).
//
// A tag can be scoped to dives, sites, or both (#1849), and deleting or
// merging it rewrites every dive and every site that carries it. Each message
// names only what is actually affected: dives, sites, both, or nothing. The
// "both" variants are single ICU messages with two plurals rather than two
// phrases joined here, so every locale controls its own word order.

/// The confirmation for deleting one tag.
String tagDeleteMessage(
  AppLocalizations l10n,
  String tagName, {
  required int dives,
  required int sites,
}) => switch ((dives > 0, sites > 0)) {
  (true, true) => l10n.tags_manage_deleteMessage_divesAndSites(
    tagName,
    dives,
    sites,
  ),
  (true, false) => l10n.tags_manage_deleteMessage(tagName, dives),
  (false, true) => l10n.tags_manage_deleteMessage_sites(tagName, sites),
  (false, false) => l10n.tags_manage_deleteMessage_unused(tagName),
};

/// The confirmation for deleting several tags. [dives] and [sites] are the
/// union across the selection, so an item carrying two of them counts once.
String tagsBulkDeleteMessage(
  AppLocalizations l10n, {
  required int dives,
  required int sites,
}) => switch ((dives > 0, sites > 0)) {
  (true, true) => l10n.tags_manage_bulkDeleteMessage_divesAndSites(
    dives,
    sites,
  ),
  (true, false) => l10n.tags_manage_bulkDeleteMessage(dives),
  (false, true) => l10n.tags_manage_bulkDeleteMessage_sites(sites),
  (false, false) => l10n.tags_manage_bulkDeleteMessage_unused,
};

/// The merge sheet's preview of what a merge rewrites, counted as a union
/// like [tagsBulkDeleteMessage].
String tagsMergeAffectedMessage(
  AppLocalizations l10n, {
  required int dives,
  required int sites,
}) => switch ((dives > 0, sites > 0)) {
  (true, true) => l10n.tags_manage_mergeAffected_divesAndSites(dives, sites),
  (true, false) => l10n.tags_manage_mergeAffectedDives(dives),
  (false, true) => l10n.tags_manage_mergeAffected_sites(sites),
  (false, false) => l10n.tags_manage_mergeAffected_unused,
};

/// One tag's usage as a row subtitle: its dives, plus its sites when any
/// carry it. Shared by the Manage Tags list and the merge sheet.
String tagUsageCounts(
  AppLocalizations l10n, {
  required int dives,
  required int sites,
}) => [
  l10n.tags_manage_diveCount(dives),
  if (sites > 0) l10n.tags_manage_siteCount(sites),
].join(', ');
