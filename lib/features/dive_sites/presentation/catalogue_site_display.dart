import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How a built-in catalogue site is put into words on screen: in the site
/// picker's rows, on the details card and on the map.

/// The site's depth in the diver's unit: a range when it has both ends, the
/// one depth it has otherwise, null with none.
String? catalogueDepthRange(CatalogueSite site, UnitFormatter units) {
  final min = site.minDepth;
  final max = site.maxDepth;
  if (min == null && max == null) return null;
  if (min != null && max != null) {
    return '${units.formatDepth(min, decimals: 0)}'
        '–${units.formatDepth(max, decimals: 0)}';
  }
  return units.formatDepth(max ?? min, decimals: 0);
}

/// The one place name that best says where the site is: its island, else
/// its region, else its country.
String? cataloguePlace(CatalogueSite site) =>
    _firstNonBlank([site.island, site.region, site.country]);

/// Every place part the site has, most local first, each once.
String catalogueLocationLine(CatalogueSite site) {
  final parts = <String>[];
  for (final part in [site.locality, site.island, site.region, site.country]) {
    final trimmed = part?.trim() ?? '';
    if (trimmed.isNotEmpty && !parts.contains(trimmed)) parts.add(trimmed);
  }
  return parts.join(', ');
}

/// The site's types by their translated names.
List<String> catalogueTypeNames(CatalogueSite site, AppLocalizations l10n) => [
  for (final id in site.typeIds) ?builtInSiteTypeName(l10n, id),
];

/// The site's entry methods by their translated names.
List<String> catalogueEntryNames(CatalogueSite site, AppLocalizations l10n) => [
  for (final method in site.entryMethods) method.localizedName(l10n),
];

/// One line for a list row: place, entry, depth and types, leaving out
/// whatever the site lacks. Empty for a site that has only a name.
String catalogueSiteSummary(
  CatalogueSite site,
  UnitFormatter units,
  AppLocalizations l10n,
) => [
  cataloguePlace(site),
  catalogueEntryNames(site, l10n).join(', '),
  catalogueDepthRange(site, units),
  catalogueTypeNames(site, l10n).join(', '),
].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

String? _firstNonBlank(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
