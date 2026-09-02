import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_glyph.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_extra_fields.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Detailed list card for one dive site.
///
/// Configurable slots (title, subtitle, stat1, stat2, extra fields) come from
/// [siteDetailedCardConfigProvider]; the rating, shared badge, difficulty,
/// water type and feature chips are fixed identity elements. Hand-rolled
/// rather than a ListTile so the title keeps its font role under every theme
/// preset and nothing text-bearing sits in the trailing slot.
class SiteListTile extends ConsumerStatefulWidget {
  final SiteWithDiveCount entry;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isChecked;
  final bool showSharedBadge;

  const SiteListTile({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isChecked = false,
    this.showSharedBadge = false,
  });

  String get name => entry.site.name;

  @override
  ConsumerState<SiteListTile> createState() => _SiteListTileState();
}

class _SiteListTileState extends ConsumerState<SiteListTile> {
  final MapController _mapController = MapController();

  static const _contentInset = 52.0;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final site = entry.site;
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final config = ref.watch(siteDetailedCardConfigProvider);
    final accent = resolveFeatureAccent(
      context,
      ref,
      surface: AccentSurface.list,
      featureId: 'sites',
    );

    final showMapBackground = ref.watch(showMapBackgroundOnSiteCardsProvider);
    final location = site.location;
    final shouldShowMap =
        showMapBackground &&
        location != null &&
        !widget.isSelected &&
        !widget.isChecked;
    final primaryTextColor = shouldShowMap ? Colors.white : null;
    final secondaryTextColor = shouldShowMap
        ? Colors.white70
        : colorScheme.onSurfaceVariant;
    final statColor = shouldShowMap
        ? Colors.white
        : (accent ?? colorScheme.primary);

    final adapter = SiteFieldAdapter.instance;
    final slots = config.slots;
    final titleField = resolveCardSlot(slots, 'title', SiteField.siteName);
    final subtitleField = resolveCardSlot(
      slots,
      'subtitle',
      SiteField.location,
    );
    final stat1Field = resolveCardSlot(slots, 'stat1', SiteField.depthRange);
    final stat2Field = resolveCardSlot(slots, 'stat2', SiteField.diveCount);

    String? slotText(SiteField field) {
      final value = adapter.extractValue(field, entry);
      if (value == null) return null;
      final text = adapter.formatValue(field, value, units);
      return text.isEmpty ? null : text;
    }

    final title = slotText(titleField) ?? site.name;
    final subtitle = slotText(subtitleField);

    String formatStat(SiteField field, dynamic value) {
      if (field == SiteField.diveCount) {
        return l10n.diveSites_list_tile_diveCount(value as int);
      }
      return adapter.formatValue(field, value, units);
    }

    Widget stat(SiteField field) {
      // A count of zero reads as noise on a card; the site simply has no
      // dives yet, which the missing "Last dived" already says.
      if (field == SiteField.diveCount && entry.diveCount == 0) {
        return const SizedBox.shrink();
      }
      return EntityCardStat<SiteWithDiveCount, SiteField>(
        adapter: adapter,
        entity: entry,
        field: field,
        units: units,
        color: statColor,
        formatter: formatStat,
      );
    }

    final chipTextColor = primaryTextColor ?? colorScheme.onSurface;
    final chips = <Widget>[
      if (site.difficulty != null)
        _SiteChip(
          icon: Icons.signal_cellular_alt,
          label: site.difficulty!.localizedName(l10n),
          color: statColor,
          textColor: chipTextColor,
        ),
      if (site.waterType != null)
        _SiteChip(
          icon: Icons.water_drop,
          label: site.waterType!.localizedName(l10n),
          color: statColor,
          textColor: chipTextColor,
        ),
      for (final typeName in entry.featureTypes)
        _SiteChip(
          icon: SiteFeatureGlyph.styleFor(typeName).$1,
          label: siteFeatureTypeLabel(l10n, typeName),
          color: SiteFeatureGlyph.styleFor(typeName).$2,
          textColor: chipTextColor,
        ),
    ];

    Widget buildContent() {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SelectionLeading(
                      isSelectionMode: widget.isSelectionMode,
                      isChecked: widget.isChecked,
                      onChanged: (_) => widget.onTap?.call(),
                      child: CircleAvatar(
                        backgroundColor:
                            accent?.withValues(alpha: 0.15) ??
                            colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.location_on,
                          color: accent ?? colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: primaryTextColor,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (site.rating != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              site.rating!.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: primaryTextColor),
                            ),
                          ],
                          if (widget.showSharedBadge) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: l10n
                                  .accessibility_label_sharedWithAllProfiles,
                              child: Icon(
                                Icons.people_outline,
                                size: 16,
                                color: primaryTextColor ?? colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: secondaryTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!widget.isSelectionMode)
                  ExcludeSemantics(
                    child: Icon(Icons.chevron_right, color: secondaryTextColor),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _contentInset),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 6,
                children: [stat(stat1Field), stat(stat2Field)],
              ),
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: _contentInset),
                child: Wrap(spacing: 6, runSpacing: 4, children: chips),
              ),
            ],
            if (config.extraFields.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: _contentInset),
                child: EntityCardExtraFields<SiteWithDiveCount, SiteField>(
                  adapter: adapter,
                  entity: entry,
                  fields: config.extraFields,
                  units: units,
                  labelColor: secondaryTextColor,
                  valueColor: primaryTextColor ?? colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final semanticsLabel = [
      l10n.diveSites_list_tile_semantics(site.name),
      ?subtitle,
      if (entry.diveCount > 0)
        l10n.diveSites_list_tile_diveCount(entry.diveCount),
    ].join(', ');

    if (shouldShowMap) {
      final siteLocation = LatLng(location.latitude, location.longitude);
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          selected: widget.isSelected,
          label: semanticsLabel,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TrackpadZoomMap(
                    controller: _mapController,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: siteLocation,
                        initialZoom: 13.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: ref.watch(mapTileUrlProvider),
                          userAgentPackageName: 'app.submersion',
                          maxZoom: ref.watch(mapTileMaxZoomProvider),
                          tileProvider: TileCacheService.instance.isInitialized
                              ? TileCacheService.instance.getTileProvider()
                              : null,
                        ),
                        const MapAttribution(),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.3, 0.7, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                buildContent(),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: widget.isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : widget.isChecked
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Semantics(
        button: true,
        selected: widget.isSelected,
        label: semanticsLabel,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: buildContent(),
        ),
      ),
    );
  }
}

/// A small outlined chip with an icon, used for the fixed identity row
/// (difficulty, water type, site features).
class _SiteChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _SiteChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 12, color: color)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
