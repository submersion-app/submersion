import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/reveal_collapsed_toggle.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One species chip in a section of a site's Marine life card.
class SiteSpeciesChipData {
  final String name;
  final SpeciesCategory category;

  /// Times spotted at the site, shown after the name; null shows none.
  final int? count;

  const SiteSpeciesChipData({
    required this.name,
    required this.category,
    this.count,
  });
}

/// A section's species on a site's Marine life card, grouped by category,
/// each category's name in a column beside its chips (issue #5128).
///
/// Stacked above their chips, the names ran together with the section
/// titles, and a category of one species took two lines. The names sit on
/// the baseline of their first row of chips.
///
/// A long section shows its first [collapsedLimit] species with a Show all
/// toggle, as Recorded nearby does beneath it, so a site with hundreds of
/// species logged does not run the card to thousands of pixels. Give it a
/// key per site, so another site opens collapsed.
class SiteSpeciesChipGroups extends StatefulWidget {
  /// In display order: categories appear in the order of their first
  /// species.
  final List<SiteSpeciesChipData> species;

  const SiteSpeciesChipGroups({super.key, required this.species});

  /// As many chips as Recorded nearby shows collapsed.
  static const int collapsedLimit = 12;

  @override
  State<SiteSpeciesChipGroups> createState() => _SiteSpeciesChipGroupsState();
}

class _SiteSpeciesChipGroupsState extends State<SiteSpeciesChipGroups> {
  /// Between a category's name and its chips.
  static const double _categoryGap = 12;

  bool _expanded = false;

  /// The Show all / Show fewer button, brought back into view on Show fewer.
  final GlobalKey _toggleKey = GlobalKey();

  void _toggle() {
    final collapsing = _expanded;
    setState(() => _expanded = !_expanded);
    if (collapsing) revealCollapsedToggle(_toggleKey);
  }

  @override
  void didUpdateWidget(SiteSpeciesChipGroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A list that fits loses its toggle, and with it the expanded state, so
    // one that grows long again opens collapsed.
    if (widget.species.length <= SiteSpeciesChipGroups.collapsedLimit) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final species = widget.species;
    final hidden = species.length - SiteSpeciesChipGroups.collapsedLimit;

    final grouped = <SpeciesCategory, List<SiteSpeciesChipData>>{};
    for (final s in species) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }
    // Cut in the order the chips are drawn, so Show all only adds chips
    // after those already shown. A category the cut leaves out entirely
    // drops out with its name.
    var room = _expanded || hidden <= 0
        ? species.length
        : SiteSpeciesChipGroups.collapsedLimit;
    final groups = <MapEntry<SpeciesCategory, List<SiteSpeciesChipData>>>[];
    for (final entry in grouped.entries) {
      if (room <= 0) break;
      final taken = entry.value.take(room).toList();
      groups.add(MapEntry(entry.key, taken));
      room -= taken.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTable(context, groups),
        if (hidden > 0)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: _toggleKey,
              onPressed: _toggle,
              child: Text(
                _expanded
                    ? context.l10n.marineLife_speciesDetail_showFewer
                    : context.l10n.marineLife_speciesDetail_showAll(
                        species.length,
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<MapEntry<SpeciesCategory, List<SiteSpeciesChipData>>> groups,
  ) {
    return Table(
      // Wide enough for any category's name, so every section starts its
      // chips in one column down the card, but never more than about a
      // third of it: a long translation wraps rather than crowding the
      // chips on a phone.
      columnWidths: {
        0: MinColumnWidth(
          FixedColumnWidth(_categoryColumnWidth(context)),
          const FractionColumnWidth(0.35),
        ),
        1: const FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (final (index, entry) in groups.indexed)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: _categoryGap,
                  bottom: index == groups.length - 1 ? 0 : 8,
                ),
                child: Text(
                  entry.key.localizedName(context.l10n),
                  style: _categoryStyle(context),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == groups.length - 1 ? 0 : 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final s in entry.value) _speciesChip(context, s),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  TextStyle? _categoryStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// The widest category name in this language, at the diver's text size,
  /// plus the gap before the chips. Measured over every category, not just
  /// those listed, so Spotted and Expected arrive at the same width.
  double _categoryColumnWidth(BuildContext context) {
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(_categoryStyle(context));
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    var widest = 0.0;
    for (final category in SpeciesCategory.values) {
      painter
        ..text = TextSpan(
          text: category.localizedName(context.l10n),
          style: style,
        )
        ..layout();
      widest = math.max(widest, painter.width);
    }
    painter.dispose();
    return widest.ceilToDouble() + _categoryGap;
  }

  Widget _speciesChip(BuildContext context, SiteSpeciesChipData s) {
    final theme = Theme.of(context);
    final count = s.count;
    // The one announcement for the chip: Chip builds a container node of
    // its own, so its visible label would otherwise be read a second time.
    // Nothing on the chip is tappable, so excluding it loses no action.
    return Semantics(
      excludeSemantics: true,
      label: count != null
          ? context.l10n.marineLife_siteSection_spottedCountSemantics(
              s.name,
              count,
            )
          : s.name,
      child: Chip(
        avatar: ExcludeSemantics(
          child: Icon(
            iconForSpeciesCategory(s.category),
            size: 16,
            // The app's one colour per category, as Recorded nearby below
            // draws it.
            color: colorForSpeciesCategory(s.category, theme.brightness),
          ),
        ),
        // A chip fades a label it cannot fit on one line, which on a
        // phone cut the count off a long name. It wraps instead. A null
        // maxLines would take the chip's one line, so the cap is explicit.
        label: Text(
          count != null ? '${s.name} ($count)' : s.name,
          style: theme.textTheme.bodySmall,
          softWrap: true,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
