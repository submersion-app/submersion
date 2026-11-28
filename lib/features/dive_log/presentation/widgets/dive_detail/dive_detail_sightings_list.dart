import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_sighting_row.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A list longer than this starts collapsed (issue #5067).
const kSightingsCollapseAbove = 10;

/// How many species a collapsed list shows. Below [kSightingsCollapseAbove]
/// so the toggle always hides at least three rows, never just one or two.
const kSightingsCollapsedCount = 8;

/// The card width from which the species sit in two columns. A phone, or a
/// narrow detail pane, keeps one.
const kSightingsTwoColumnMinWidth = 600.0;

const double _columnGap = 16;

/// The species on the Marine life card of the dive page.
///
/// A reef survey can log dozens of species, and one row each made the card
/// the tallest thing on the page (issue #5067). So a wide card lays them out
/// in two columns, and a list of more than [kSightingsCollapseAbove] shows
/// the first [kSightingsCollapsedCount] behind a Show all toggle.
class DiveSightingsList extends StatefulWidget {
  const DiveSightingsList({
    super.key,
    required this.sightings,
    required this.photoCounts,
    required this.onOpen,
    required this.onOpenPhotos,
  });

  final List<Sighting> sightings;

  /// Photos on the dive tagged with each species, by species id.
  final Map<String, int> photoCounts;

  /// Tapping a row.
  final void Function(Sighting sighting) onOpen;

  /// Tapping a row's photo chip.
  final void Function(Sighting sighting) onOpenPhotos;

  @override
  State<DiveSightingsList> createState() => _DiveSightingsListState();
}

class _DiveSightingsListState extends State<DiveSightingsList> {
  var _expanded = false;
  final _toggleKey = GlobalKey();

  void _toggle() {
    final collapsing = _expanded;
    setState(() => _expanded = !_expanded);
    if (!collapsing) return;
    // Folding a long list removes the rows above the button, which leaves a
    // reader who scrolled down to it far past the card. Bring it back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final toggle = _toggleKey.currentContext;
      if (toggle == null || !toggle.mounted) return;
      Scrollable.ensureVisible(
        toggle,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = widget.sightings;
    final collapsible = all.length > kSightingsCollapseAbove;
    final shown = collapsible && !_expanded
        ? all.take(kSightingsCollapsedCount).toList()
        : all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns =
                constraints.maxWidth >= kSightingsTwoColumnMinWidth;
            final rowWidth = twoColumns
                ? (constraints.maxWidth - _columnGap) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: _columnGap,
              children: [
                for (final sighting in shown)
                  SizedBox(width: rowWidth, child: _row(sighting)),
              ],
            );
          },
        ),
        if (collapsible)
          TextButton.icon(
            key: _toggleKey,
            onPressed: _toggle,
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _expanded
                  ? l10n.marineLife_speciesDetail_showFewer
                  : l10n.marineLife_speciesDetail_showAll(all.length),
            ),
          ),
      ],
    );
  }

  Widget _row(Sighting sighting) => DiveSightingRow(
    sighting: sighting,
    photoCount: widget.photoCounts[sighting.speciesId] ?? 0,
    onOpen: () => widget.onOpen(sighting),
    onOpenPhotos: () => widget.onOpenPhotos(sighting),
  );
}
