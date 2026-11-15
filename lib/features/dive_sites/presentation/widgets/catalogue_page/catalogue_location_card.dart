import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/catalogue_site_page_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_page_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';

/// Where a built-in site is: its place names and its coordinates, each row
/// only when the record has it. The coordinates row can be copied, by its
/// button or a long press.
///
/// The sea is named in the diver's place-name language, as the site would
/// have it once added. The other place names are the catalogue's own.
class CatalogueLocationCard extends ConsumerWidget {
  const CatalogueLocationCard({super.key, required this.site});

  final CatalogueSite site;

  /// Whether [site] has a place name or a position for this card to show.
  /// The page asks this and leaves the card out when it has neither: the
  /// card itself always has a row.
  static bool hasContent(CatalogueSite site) =>
      site.location != null ||
      [
        site.country,
        site.region,
        site.locality,
        site.island,
        site.bodyOfWater,
      ].any((part) => part?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final sea =
        ref.watch(catalogueSeaNameProvider(site.id)).value ?? site.bodyOfWater;
    final location = site.location;
    final coordinates = location == null
        ? null
        : units.formatCoordinates(location.latitude, location.longitude);

    final rows = [
      _row(
        context,
        Icons.flag,
        l10n.diveSites_detail_location_country,
        site.country,
      ),
      _row(
        context,
        Icons.place,
        l10n.diveSites_detail_location_region,
        site.region,
      ),
      _row(
        context,
        Icons.location_city,
        l10n.diveSites_detail_location_city,
        site.locality,
      ),
      _row(
        context,
        Icons.landscape,
        l10n.diveSites_detail_location_island,
        site.island,
      ),
      _row(
        context,
        Icons.waves,
        l10n.diveSites_detail_location_bodyOfWater,
        sea,
      ),
      // Worth pasting elsewhere (a chartplotter, a message to a buddy).
      _row(
        context,
        Icons.gps_fixed,
        l10n.diveSites_detail_location_gpsCoordinates,
        coordinates,
        copyable: true,
      ),
    ].whereType<Widget>().toList();

    return CataloguePageCard(
      icon: Icons.map,
      title: l10n.diveSites_detail_section_location,
      children: [
        DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          ),
        ),
      ],
    );
  }

  /// One row, or null when the record has no [value] for it. A
  /// [copyable] row is the shared copyable detail row: its button, or a
  /// long press, copies the value and confirms it.
  Widget? _row(
    BuildContext context,
    IconData icon,
    String label,
    String? value, {
    bool copyable = false,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return DetailRow.text(
      icon: icon,
      iconSize: 18,
      iconColor: muted,
      label: label,
      labelStyle: theme.textTheme.bodySmall?.copyWith(color: muted),
      padding: const EdgeInsets.symmetric(vertical: 6),
      value: text,
      valueStyle: theme.textTheme.bodyMedium,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      copyable: copyable,
    );
  }
}
