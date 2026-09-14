import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// The wording each tag scope brings to the tag screens (issue #1942). One
// exhaustive switch per phrase, so a new scope does not compile until it has
// all of its wording.

/// The scope's name in a tag's "Dives · Sites" line.
String tagScopeName(AppLocalizations l10n, TagScope scope) => switch (scope) {
  TagScope.dives => l10n.tags_manage_scope_dives,
  TagScope.sites => l10n.tags_manage_scope_sites,
  TagScope.equipment => l10n.tags_manage_scope_equipment,
};

/// The scope's checkbox in the tag editor.
String tagScopeUseForLabel(AppLocalizations l10n, TagScope scope) =>
    switch (scope) {
      TagScope.dives => l10n.tags_manage_useForDives,
      TagScope.sites => l10n.tags_manage_useForSites,
      TagScope.equipment => l10n.tags_manage_useForEquipment,
    };

/// How many items of the scope carry a tag, such as "3 sites".
String tagScopeCount(AppLocalizations l10n, TagScope scope, int count) =>
    switch (scope) {
      TagScope.dives => l10n.tags_manage_diveCount(count),
      TagScope.sites => l10n.tags_manage_siteCount(count),
      TagScope.equipment => l10n.tags_manage_equipmentCount(count),
    };

/// What turning the scope off removes, for the narrowing confirmation.
String tagScopeNarrowLine(AppLocalizations l10n, TagScope scope, int count) =>
    switch (scope) {
      TagScope.dives => l10n.tags_manage_narrowDialog_dives(count),
      TagScope.sites => l10n.tags_manage_narrowDialog_sites(count),
      TagScope.equipment => l10n.tags_manage_narrowDialog_equipment(count),
    };
