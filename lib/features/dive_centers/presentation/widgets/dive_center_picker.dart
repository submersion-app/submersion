import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/services/dive_center_picker_ranking.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A bottom sheet widget for selecting a dive center from a list.
///
/// With a [reference] the centers near the dive come first, nearest at the
/// top with their distance, then every other center alphabetically (#3379).
/// Permanently closed centers are greyed at the bottom, still selectable.
class DiveCenterPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final DiveCenter? selectedCenter;
  final ValueChanged<DiveCenter> onCenterSelected;
  final VoidCallback onCreateNewCenter;

  /// Where "nearby" is measured from; null lists every center
  /// alphabetically with no sections.
  final DiveCenterPickerReference? reference;

  const DiveCenterPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedCenter,
    required this.onCenterSelected,
    required this.onCreateNewCenter,
    this.reference,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centersAsync = ref.watch(allDiveCentersProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Column(
      children: [
        // Handle bar
        ExcludeSemantics(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title and add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Shrinks before the button, so a long translation cannot push
              // "New Dive Center" off the sheet.
              Flexible(
                child: Text(
                  context.l10n.diveCenters_picker_title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: onCreateNewCenter,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.diveCenters_picker_newCenter),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Dive center list
        Expanded(
          child: centersAsync.when(
            data: (centers) {
              if (centers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.store,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.diveCenters_empty_title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onCreateNewCenter,
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.diveCenters_title_add),
                      ),
                    ],
                  ),
                );
              }

              final sections = rankDiveCentersForPicker(
                centers,
                reference: reference,
              );
              final l10n = context.l10n;
              final items = <Widget Function()>[
                if (sections.nearby.isNotEmpty) ...[
                  () => _SectionHeader(_nearbyHeading(l10n)),
                  for (final near in sections.nearby)
                    () => _buildRow(
                      context,
                      near.center,
                      distance: units.formatGeoDistance(near.distanceMeters),
                    ),
                  if (sections.others.isNotEmpty)
                    () => _SectionHeader(l10n.diveCenters_picker_allCenters),
                ],
                for (final other in sections.others)
                  () => _buildRow(context, other),
              ];

              return ListView.builder(
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) => items[index](),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                context.l10n.diveCenters_error_loading(error.toString()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _nearbyHeading(AppLocalizations l10n) {
    final siteName = reference?.siteName;
    if (siteName != null) return l10n.diveCenters_picker_nearSite(siteName);
    return reference?.source == DiveCenterReferenceSource.device
        ? l10n.diveCenters_picker_nearYourLocation
        : l10n.diveCenters_picker_nearThisDive;
  }

  Widget _buildRow(
    BuildContext context,
    DiveCenter center, {
    String? distance,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selectedCenter?.id == center.id;
    final closed = center.isPermanentlyClosed;

    final tile = Semantics(
      button: true,
      label: [
        center.name,
        if (closed) context.l10n.diveCenters_tag_closed,
        if (center.displayLocation != null) center.displayLocation!,
        ?distance,
        if (isSelected) context.l10n.diveCenters_accessibility_selected,
      ].join(', '),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? colorScheme.primary
              : colorScheme.primaryContainer,
          child: Icon(
            Icons.store,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onPrimaryContainer,
          ),
        ),
        title: DiveCenterNameWithTag(closed: closed, name: Text(center.name)),
        subtitle: center.displayLocation != null
            ? Text(center.displayLocation!)
            : null,
        trailing: distance == null && !isSelected
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (distance != null)
                    Text(
                      distance,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (distance != null && isSelected) const SizedBox(width: 8),
                  if (isSelected)
                    Icon(Icons.check_circle, color: colorScheme.primary),
                ],
              ),
        onTap: () => onCenterSelected(center),
      ),
    );
    return greyIfClosed(closed: closed, child: tile);
  }
}

/// A picker section heading: "Near Salt Pier", "All dive centers".
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
