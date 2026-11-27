import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/marine_life/presentation/widgets/sighting_amount_badge.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One sighting on the dive detail page: the category avatar, the localized
/// species name, the note, how many animals (an exact count or a REEF
/// group; nothing for Seen), when the dive's photos carry this species' tag
/// a chip that opens those photos, and, when it has a place on the profile,
/// how deep it was seen (issue #5092).
class DiveSightingRow extends StatelessWidget {
  const DiveSightingRow({
    super.key,
    required this.sighting,
    required this.photoCount,
    required this.onOpen,
    this.onOpenPhotos,
    this.depthLabel,
    this.depthSelected = false,
    this.onToggleDepth,
    this.seenAtLabel,
  });

  final Sighting sighting;

  /// Photos on this dive tagged with the sighting's species. The chip only
  /// appears for a positive count with an [onOpenPhotos] to call.
  final int photoCount;

  /// Tapping the row: opens the species detail.
  final VoidCallback onOpen;

  /// Tapping the photo chip.
  final VoidCallback? onOpenPhotos;

  /// How deep the species was seen (`27 m`, `16 to 18 m`), or null when it
  /// has no place on the profile.
  final String? depthLabel;

  /// Whether the species is highlighted on the profile.
  final bool depthSelected;

  /// Toggles the highlight. Null when no profile can show it: the depth is
  /// then a plain label.
  final VoidCallback? onToggleDepth;

  /// When it was seen, for a dive with no profile to place it on
  /// (`at 12:30`), or null.
  final String? seenAtLabel;

  /// Below this width the chips sit under the name instead of beside it.
  static const double _compactWidth = 420;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = localizedSpeciesName(
      l10n,
      sighting.speciesId,
      sighting.speciesName,
    );
    final onOpenPhotos = this.onOpenPhotos;
    final depthLabel = this.depthLabel;
    final onToggleDepth = this.onToggleDepth;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final chips = <Widget>[
      if (depthLabel != null)
        if (onToggleDepth != null)
          // Its own node: a screen reader reaches it apart from the row,
          // and activating it toggles rather than opening the species.
          Semantics(
            container: true,
            button: true,
            selected: depthSelected,
            onTap: onToggleDepth,
            label: l10n.diveLog_detail_semantics_showOnProfile(
              name,
              depthLabel,
            ),
            excludeSemantics: true,
            child: FilterChip(
              key: const ValueKey('sighting_depth'),
              avatar: const Icon(Icons.show_chart, size: 16),
              showCheckmark: false,
              selected: depthSelected,
              label: Text(depthLabel),
              onSelected: (_) => onToggleDepth(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          )
        else
          Text(depthLabel, style: muted),
      if (photoCount > 0 && onOpenPhotos != null)
        ActionChip(
          key: const ValueKey('sighting_photos'),
          avatar: const Icon(Icons.photo_outlined, size: 16),
          label: Text(l10n.diveLog_detail_sightingPhotos(photoCount)),
          onPressed: onOpenPhotos,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
    ];

    Widget details({required bool chipsBelow}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        if (seenAtLabel case final seenAt?) Text(seenAt, style: muted),
        if (sighting.notes.isNotEmpty)
          Text(
            sighting.notes,
            style: muted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (chipsBelow && chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: chips,
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      label: l10n.diveLog_detail_semantics_viewSpecies(name),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < _compactWidth;
              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorForSpeciesCategory(
                      sighting.speciesCategory,
                      theme.brightness,
                    ),
                    child: Icon(
                      iconForSpeciesCategory(
                        sighting.speciesCategory ?? SpeciesCategory.other,
                      ),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: details(chipsBelow: compact)),
                  if (!compact)
                    for (final chip in chips)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: chip,
                      ),
                  if (sighting.abundance != SightingAbundance.seen)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: SightingAmountBadge(amount: sighting.amount),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
