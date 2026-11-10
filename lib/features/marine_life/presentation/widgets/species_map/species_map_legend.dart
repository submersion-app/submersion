import 'package:flutter/material.dart';

import 'package:submersion/features/reef/presentation/widgets/reef_attribution_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Names what each mark on the species map means.
///
/// The public records swatch shows only in species mode with the layer on:
/// the places view draws no public tiles. The GBIF credit shows in either
/// mode while the layer is on.
class SpeciesMapLegend extends StatelessWidget {
  final bool speciesMode;
  final bool publicOn;

  const SpeciesMapLegend({
    super.key,
    required this.speciesMode,
    required this.publicOn,
  });

  /// GBIF's own `orange.marker` tile colour, for the public records swatch.
  static const Color publicRecordsColor = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[
      if (!speciesMode)
        _row(
          context,
          _dot(fill: scheme.primary, border: scheme.surface),
          l10n.speciesMap_legend_speciesLogged,
        ),
      if (speciesMode) ...[
        _row(
          context,
          _dot(fill: scheme.primary, border: scheme.surface),
          l10n.speciesMap_legend_mySightings,
        ),
        _row(
          context,
          _dot(fill: scheme.surface, border: scheme.primary),
          l10n.speciesMap_legend_expected,
        ),
        if (publicOn)
          _row(
            context,
            Container(
              width: 12,
              height: 12,
              color: publicRecordsColor.withValues(alpha: 0.7),
            ),
            l10n.speciesMap_legend_publicRecords,
          ),
      ],
      // GBIF asks to be credited wherever its records are shown: the public
      // tiles in species mode, the site cards' nearby lists in places mode.
      // The reef sources sheet already names it and its licence filter.
      if (publicOn)
        TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => const ReefAttributionSheet(),
          ),
          child: Text(l10n.speciesMap_attribution),
        ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }

  static Widget _dot({required Color fill, required Color border}) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: fill,
      shape: BoxShape.circle,
      border: Border.all(color: border, width: 2),
    ),
  );

  static Widget _row(BuildContext context, Widget swatch, String label) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: swatch),
            const SizedBox(width: 8),
            // Wraps rather than overflows in a narrow corner or a long
            // translation.
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      );
}
