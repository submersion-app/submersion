import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Wording for what deleting or merging tags touches (#1902).
//
// A tag can be scoped to dives, sites, or both (#1849), and deleting or
// merging it rewrites every dive and every site that carries it. Each message
// names only what is actually affected: dives, sites, both, or nothing. The
// "both" variants are single ICU messages with two plurals rather than two
// phrases joined here, so every locale controls its own word order.
//
// Usage arrives as a map per scope (#1942). A scope the map lacks counts as
// zero.

int _count(Map<TagScope, int> usage, TagScope scope) => usage[scope] ?? 0;

/// The confirmation for deleting one tag.
String tagDeleteMessage(
  AppLocalizations l10n,
  String tagName,
  Map<TagScope, int> usage,
) {
  final dives = _count(usage, TagScope.dives);
  final sites = _count(usage, TagScope.sites);
  return switch ((dives > 0, sites > 0)) {
    (true, true) => l10n.tags_manage_deleteMessage_divesAndSites(
      tagName,
      dives,
      sites,
    ),
    (true, false) => l10n.tags_manage_deleteMessage(tagName, dives),
    (false, true) => l10n.tags_manage_deleteMessage_sites(tagName, sites),
    (false, false) => l10n.tags_manage_deleteMessage_unused(tagName),
  };
}

/// The confirmation for deleting several tags. [usage] is the union across
/// the selection, so an item carrying two of them counts once.
String tagsBulkDeleteMessage(AppLocalizations l10n, Map<TagScope, int> usage) {
  final dives = _count(usage, TagScope.dives);
  final sites = _count(usage, TagScope.sites);
  return switch ((dives > 0, sites > 0)) {
    (true, true) => l10n.tags_manage_bulkDeleteMessage_divesAndSites(
      dives,
      sites,
    ),
    (true, false) => l10n.tags_manage_bulkDeleteMessage(dives),
    (false, true) => l10n.tags_manage_bulkDeleteMessage_sites(sites),
    (false, false) => l10n.tags_manage_bulkDeleteMessage_unused,
  };
}

/// The merge sheet's preview of what a merge rewrites, counted as a union
/// like [tagsBulkDeleteMessage].
String tagsMergeAffectedMessage(
  AppLocalizations l10n,
  Map<TagScope, int> usage,
) {
  final dives = _count(usage, TagScope.dives);
  final sites = _count(usage, TagScope.sites);
  return switch ((dives > 0, sites > 0)) {
    (true, true) => l10n.tags_manage_mergeAffected_divesAndSites(dives, sites),
    (true, false) => l10n.tags_manage_mergeAffectedDives(dives),
    (false, true) => l10n.tags_manage_mergeAffected_sites(sites),
    (false, false) => l10n.tags_manage_mergeAffected_unused,
  };
}

/// One tag's usage as a row subtitle, in registry order: its dives always,
/// and every other scope when something carries the tag. Shared by the
/// Manage Tags list and the merge sheet.
String tagUsageCounts(AppLocalizations l10n, Map<TagScope, int> usage) => [
  for (final scope in TagScope.values)
    if (scope == TagScope.dives || _count(usage, scope) > 0)
      tagScopeCount(l10n, scope, _count(usage, scope)),
].join(', ');
