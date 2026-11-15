import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_nearby.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_kind_glyph.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_page_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What lies near a built-in site: the diver's own sites, then other
/// built-in sites, each with its distance. A row opens that site's page,
/// the diver's own or the built-in one.
///
/// Absent when there is nothing near.
class CatalogueNearbyCard extends ConsumerWidget {
  const CatalogueNearbyCard({super.key, required this.nearby});

  final CatalogueNearby nearby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (nearby.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);

    return CataloguePageCard(
      icon: Icons.near_me_outlined,
      title: l10n.diveSites_picker_nearby,
      children: [
        if (nearby.yours.isNotEmpty) ...[
          _Heading(l10n.diveSites_builtInPage_nearbyYours),
          for (final own in nearby.yours)
            _NearbyRow(
              key: ValueKey('catalogueNearbyOwn_${own.site.id}'),
              icon: Icons.location_on,
              own: true,
              name: own.site.name,
              detail: own.diveCount > 0
                  ? l10n.diveSites_map_infoCard_diveCount(own.diveCount)
                  : null,
              distance: units.formatGeoDistance(own.meters),
              onTap: () => context.push('/sites/${own.site.id}'),
            ),
        ],
        if (nearby.yours.isNotEmpty && nearby.builtIn.isNotEmpty)
          const SizedBox(height: 8),
        if (nearby.builtIn.isNotEmpty) ...[
          _Heading(l10n.diveSites_picker_builtIn_search),
          for (final other in nearby.builtIn)
            _NearbyRow(
              key: ValueKey('catalogueNearbyRecord_${other.record.id}'),
              icon: catalogueKindIcon(other.record.kind),
              own: false,
              name: other.record.name,
              detail: null,
              distance: units.formatGeoDistance(other.meters),
              onTap: () => context.push(catalogueSitePath(other.record.id)),
            ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One neighbour: its glyph, name, an optional detail, and how far it is.
/// The distance is plain text at the end of the row, not a button or chip.
class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    super.key,
    required this.icon,
    required this.own,
    required this.name,
    required this.detail,
    required this.distance,
    required this.onTap,
  });

  final IconData icon;

  /// One of the diver's own sites, drawn in the primary colour as their
  /// markers are; a built-in record is drawn muted, as its pin is.
  final bool own;
  final String name;
  final String? detail;
  final String distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      // Six of these sit one under another: each is tall enough to hit.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: own ? theme.colorScheme.primary : muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                detail == null ? name : '$name · $detail',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              distance,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            Icon(Icons.chevron_right, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}
