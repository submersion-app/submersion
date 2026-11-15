import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_page_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the catalogue says a built-in site is: its types, entry, depth
/// and, for fresh water, its water type, then its description.
///
/// Most dive site records have none of them. The page asks [hasContent]
/// and leaves the card out, so it is never drawn empty.
class CatalogueAboutCard extends ConsumerWidget {
  const CatalogueAboutCard({super.key, required this.site});

  final CatalogueSite site;

  /// Whether [site] has anything for this card to show. A type counts
  /// only when it has a name to show: a type id a later catalogue adds,
  /// which this version cannot name, must not leave a card with a title
  /// and nothing under it.
  static bool hasContent(CatalogueSite site, AppLocalizations l10n) =>
      catalogueTypeNames(site, l10n).isNotEmpty ||
      site.entryMethods.isNotEmpty ||
      site.minDepth != null ||
      site.maxDepth != null ||
      site.waterType == WaterType.fresh ||
      (site.description?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final depth = catalogueDepthRange(site, ref.watch(unitFormatterProvider));
    // The catalogue says salt for no record, so only fresh is worth a chip.
    final water = site.waterType == WaterType.fresh
        ? WaterType.fresh.localizedName(l10n)
        : null;
    final facts = [
      ...catalogueTypeNames(site, l10n),
      ...catalogueEntryNames(site, l10n),
      ?depth,
      ?water,
    ];
    final description = site.description?.trim() ?? '';

    return CataloguePageCard(
      icon: Icons.description,
      title: l10n.diveSites_builtInPage_about,
      children: [
        if (facts.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [for (final fact in facts) CatalogueFactChip(fact)],
          ),
        if (facts.isNotEmpty && description.isNotEmpty)
          const SizedBox(height: 12),
        if (description.isNotEmpty)
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// A built-in site's hazards, as the source or the register states them.
/// The page asks [hasContent] and leaves the card out for a record with
/// none.
class CatalogueHazardsCard extends StatelessWidget {
  const CatalogueHazardsCard({super.key, required this.site});

  final CatalogueSite site;

  static bool hasContent(CatalogueSite site) =>
      site.hazards?.trim().isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    return CataloguePageCard(
      icon: Icons.warning_amber,
      title: context.l10n.diveSites_detail_section_hazards,
      warning: true,
      children: [
        Text(site.hazards!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
