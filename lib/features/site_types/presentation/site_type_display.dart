import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized names for the built-in site types, keyed on the stable slug.
///
/// Built-ins are stored with English names because exports carry the stored
/// name; on-screen callers resolve through here (the #643 lesson from dive
/// types). Returns null for anything that is not a built-in slug.
String? builtInSiteTypeName(AppLocalizations l10n, String id) => switch (id) {
  'reef' => l10n.siteType_builtin_reef,
  'wall' => l10n.siteType_builtin_wall,
  'wreck' => l10n.siteType_builtin_wreck,
  'artificial_reef' => l10n.siteType_builtin_artificial_reef,
  'cave' => l10n.siteType_builtin_cave,
  'cavern' => l10n.siteType_builtin_cavern,
  'cenote' => l10n.siteType_builtin_cenote,
  'blue_hole' => l10n.siteType_builtin_blue_hole,
  'lake' => l10n.siteType_builtin_lake,
  'quarry' => l10n.siteType_builtin_quarry,
  'river' => l10n.siteType_builtin_river,
  'spring' => l10n.siteType_builtin_spring,
  'pool' => l10n.siteType_builtin_pool,
  'pier' => l10n.siteType_builtin_pier,
  'muck' => l10n.siteType_builtin_muck,
  'kelp_forest' => l10n.siteType_builtin_kelp_forest,
  _ => null,
};

extension SiteTypeDisplay on SiteTypeEntity {
  /// The translated name for a built-in, the diver's own name otherwise.
  String localizedName(AppLocalizations l10n) =>
      isBuiltIn ? (builtInSiteTypeName(l10n, id) ?? name) : name;
}
