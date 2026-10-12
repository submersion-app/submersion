import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for [SiteGroupBy].
///
/// The switch is exhaustive by enum value, so adding a grouping is a compile
/// error until its localization key is wired in.
extension SiteGroupByDisplay on SiteGroupBy {
  String localizedName(AppLocalizations l10n) => switch (this) {
    SiteGroupBy.none => l10n.diveSites_list_groupBy_none,
    SiteGroupBy.location => l10n.diveSites_list_groupBy_location,
    SiteGroupBy.water => l10n.diveSites_list_groupBy_water,
    SiteGroupBy.locationAndWater =>
      l10n.diveSites_list_groupBy_locationAndWater,
    SiteGroupBy.library => l10n.sharedLibrary_groupBy_library,
  };

  /// The label for this mode's ungrouped group: body of water for the
  /// water-only mode, country for the two country-based modes. Never called
  /// for [SiteGroupBy.none], which has no groups.
  String noGroupLabel(AppLocalizations l10n) => switch (this) {
    SiteGroupBy.water => l10n.diveSites_group_noBodyOfWater,
    SiteGroupBy.library => l10n.sharedLibrary_groupBy_personalGroup,
    SiteGroupBy.none ||
    SiteGroupBy.location ||
    SiteGroupBy.locationAndWater => l10n.diveSites_group_noCountry,
  };

  /// The label for this mode's ungrouped *subgroup*, when it bundles one
  /// (see [bundlesUnlabeledInner]) -- null for a mode that doesn't, since it
  /// never has an ungrouped subgroup to label.
  String? innerNoGroupLabel(AppLocalizations l10n) => switch (this) {
    SiteGroupBy.locationAndWater => l10n.diveSites_group_noBodyOfWater,
    SiteGroupBy.none ||
    SiteGroupBy.location ||
    SiteGroupBy.water ||
    SiteGroupBy.library => null,
  };
}
