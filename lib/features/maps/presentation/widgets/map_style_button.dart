import 'package:flutter/material.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/widgets/map_style_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// An on-map layers button that switches between street, topographic and
/// satellite basemaps (issue #3386).
///
/// The choice is written to the diver's Map style setting, the same one the
/// Settings > Appearance dropdown edits, rather than kept per map. Every map
/// builds its tile layer from that setting, so they all follow the latest
/// choice and Settings never disagrees with what the maps show.
///
/// Styled to match [MapCompassButton] so the two stack as one control column.
class MapStyleButton extends ConsumerWidget {
  const MapStyleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final current = ref.watch(settingsProvider.select((s) => s.mapStyle));

    return Material(
      color: colorScheme.surface,
      elevation: 2,
      shape: CircleBorder(side: BorderSide(color: colorScheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<MapStyle>(
        tooltip: l10n.settings_appearance_mapStyle,
        onSelected: (style) =>
            ref.read(settingsProvider.notifier).setMapStyle(style),
        itemBuilder: (context) => [
          for (final style in MapStyle.values)
            CheckedPopupMenuItem<MapStyle>(
              value: style,
              checked: style == current,
              child: Row(
                children: [
                  Icon(style.icon, size: 20),
                  const SizedBox(width: 12),
                  Text(style.label(l10n)),
                ],
              ),
            ),
        ],
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.layers_outlined,
            size: 22,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
