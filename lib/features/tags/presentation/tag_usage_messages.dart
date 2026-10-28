import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Wording for what deleting or merging tags touches (#1902, #1942, #1970).
//
// A tag can be scoped to any mix of dives, sites, equipment, media and
// documents, and deleting or merging it rewrites every item that carries it.
// Each message names only what is actually affected. A single affected scope
// gets one whole ICU message, so every locale controls its own word order.
// Two or more get a heading and one count line per scope: one message per
// combination stopped scaling at five scopes (#1970).

/// The scopes [usage] touches, in registry order. A scope missing from the
/// map counts zero.
List<TagScope> _affected(Map<TagScope, int> usage) => [
  for (final scope in TagScope.values)
    if ((usage[scope] ?? 0) > 0) scope,
];

/// [heading], then one bulleted count per affected scope, then [footer].
String _listed(
  AppLocalizations l10n,
  String heading,
  Map<TagScope, int> usage,
  List<TagScope> scopes, {
  String? footer,
}) => [
  heading,
  for (final scope in scopes) '• ${tagScopeCount(l10n, scope, usage[scope]!)}',
  ?footer,
].join('\n');

/// The confirmation for deleting one tag.
String tagDeleteMessage(
  AppLocalizations l10n,
  String tagName,
  Map<TagScope, int> usage,
) {
  final affected = _affected(usage);
  return switch (affected) {
    [] => l10n.tags_manage_deleteMessage_unused(tagName),
    [final scope] => switch (scope) {
      TagScope.dives => l10n.tags_manage_deleteMessage(tagName, usage[scope]!),
      TagScope.sites => l10n.tags_manage_deleteMessage_sites(
        tagName,
        usage[scope]!,
      ),
      TagScope.equipment => l10n.tags_manage_deleteMessage_equipment(
        tagName,
        usage[scope]!,
      ),
      TagScope.media => l10n.tags_manage_deleteMessage_media(
        tagName,
        usage[scope]!,
      ),
      TagScope.documents => l10n.tags_manage_deleteMessage_documents(
        tagName,
        usage[scope]!,
      ),
    },
    _ => _listed(
      l10n,
      l10n.tags_manage_deleteMessage_several(tagName),
      usage,
      affected,
      footer: l10n.tags_manage_cannotUndo,
    ),
  };
}

/// The confirmation for deleting several tags. [usage] is the union across
/// the selection, so an item carrying two of them counts once.
String tagsBulkDeleteMessage(AppLocalizations l10n, Map<TagScope, int> usage) {
  final affected = _affected(usage);
  return switch (affected) {
    [] => l10n.tags_manage_bulkDeleteMessage_unused,
    [final scope] => switch (scope) {
      TagScope.dives => l10n.tags_manage_bulkDeleteMessage(usage[scope]!),
      TagScope.sites => l10n.tags_manage_bulkDeleteMessage_sites(usage[scope]!),
      TagScope.equipment => l10n.tags_manage_bulkDeleteMessage_equipment(
        usage[scope]!,
      ),
      TagScope.media => l10n.tags_manage_bulkDeleteMessage_media(usage[scope]!),
      TagScope.documents => l10n.tags_manage_bulkDeleteMessage_documents(
        usage[scope]!,
      ),
    },
    _ => _listed(
      l10n,
      l10n.tags_manage_bulkDeleteMessage_several,
      usage,
      affected,
      footer: l10n.tags_manage_cannotUndo,
    ),
  };
}

/// The merge sheet's preview of what a merge rewrites, counted as a union
/// like [tagsBulkDeleteMessage].
String tagsMergeAffectedMessage(
  AppLocalizations l10n,
  Map<TagScope, int> usage,
) {
  final affected = _affected(usage);
  return switch (affected) {
    [] => l10n.tags_manage_mergeAffected_unused,
    [final scope] => switch (scope) {
      TagScope.dives => l10n.tags_manage_mergeAffectedDives(usage[scope]!),
      TagScope.sites => l10n.tags_manage_mergeAffected_sites(usage[scope]!),
      TagScope.equipment => l10n.tags_manage_mergeAffected_equipment(
        usage[scope]!,
      ),
      TagScope.media => l10n.tags_manage_mergeAffected_media(usage[scope]!),
      TagScope.documents => l10n.tags_manage_mergeAffected_documents(
        usage[scope]!,
      ),
    },
    _ => _listed(l10n, l10n.tags_manage_mergeAffected_several, usage, affected),
  };
}

/// One tag's usage as a row subtitle: every scope that carries it, in
/// registry order ("12 dives, 3 sites, 5 equipment items"). Shared by the
/// Manage Tags list and the merge sheet.
///
/// An unused tag counts zero of the first scope in [offered], so the line is
/// never empty. Dives were once counted always, which had an equipment-only
/// tag report "0 dives" under a scope line that never mentions dives (#3746).
String tagUsageCounts(
  AppLocalizations l10n,
  Map<TagScope, int> usage, {
  required Set<TagScope> offered,
}) {
  final affected = _affected(usage);
  if (affected.isEmpty) {
    final first = TagScope.values.firstWhere(
      offered.contains,
      orElse: () => TagScope.dives,
    );
    return tagScopeCount(l10n, first, 0);
  }
  return [
    for (final scope in affected) tagScopeCount(l10n, scope, usage[scope]!),
  ].join(', ');
}
