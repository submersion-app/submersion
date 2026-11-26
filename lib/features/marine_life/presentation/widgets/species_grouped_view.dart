import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/features/marine_life/domain/species_rarity.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/seen_species_tile.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_card.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/collapsible_group_header.dart';

/// The widest a card grows before another column is added: two columns on
/// a phone, five or six on a desktop.
const kSpeciesCardMaxWidth = 200.0;

/// Width of a card on a category shelf.
const kSpeciesShelfCardWidth = 160.0;

/// The Species page's cards, grouped (issue #5027): one grid for no
/// grouping, a shelf per category, and stacked sections with pinned,
/// foldable headers for First seen, Trip and Site. In list mode every
/// grouping is stacked sections of today's rows.
class SpeciesGroupedView extends StatefulWidget {
  const SpeciesGroupedView({
    super.key,
    required this.groups,
    required this.by,
    required this.grid,
    required this.pictures,
    required this.rarityOf,
    required this.onOpen,
    required this.onSeeAllCategory,
    this.covers = const {},
    this.header,
  });

  final List<SpeciesGroup> groups;
  final SpeciesGroupBy by;
  final bool grid;

  /// The picture of each species; an absent one shows the category tile.
  final Map<String, SpeciesPicture> pictures;
  final SpeciesRarity? Function(SeenSpecies entry) rarityOf;
  final ValueChanged<SeenSpecies> onOpen;
  final ValueChanged<SpeciesCategory> onSeeAllCategory;

  /// The newest tagged photo of each species, for list rows.
  final Map<String, MediaItem> covers;

  /// Scrolls above the cards (the life list header and the controls).
  final Widget? header;

  @override
  State<SpeciesGroupedView> createState() => _SpeciesGroupedViewState();
}

class _SpeciesGroupedViewState extends State<SpeciesGroupedView> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    return CustomScrollView(
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        ..._body(context),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  List<Widget> _body(BuildContext context) {
    if (widget.by == SpeciesGroupBy.none) {
      final entries = widget.groups.expand((g) => g.entries).toList();
      return [_entries(entries, const {})];
    }
    if (widget.by == SpeciesGroupBy.category && widget.grid) {
      return [
        for (final group in widget.groups)
          SliverToBoxAdapter(child: _shelf(context, group)),
      ];
    }
    return [for (final group in widget.groups) _section(context, group)];
  }

  String _label(BuildContext context, SpeciesGroup group) {
    final l10n = context.l10n;
    if (group.category != null) return group.category!.localizedName(l10n);
    if (group.year != null) return '${group.year}';
    final place = group.place;
    if (place == null) return '';
    if (place.id == null || place.name.trim().isEmpty) {
      return widget.by == SpeciesGroupBy.site
          ? l10n.marineLife_speciesPage_noSite
          : l10n.marineLife_speciesPage_noTrip;
    }
    return place.name;
  }

  Widget _card(SeenSpecies entry, {bool firstSeenHere = false}) => SpeciesCard(
    entry: entry,
    picture: widget.pictures[entry.species.id] ?? const NoPicture(),
    rarity: widget.rarityOf(entry),
    firstSeenHere: firstSeenHere,
    onTap: () => widget.onOpen(entry),
  );

  Widget _entries(List<SeenSpecies> entries, Set<String> firstSeenHere) {
    if (!widget.grid) {
      return SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return SeenSpeciesTile(
            entry: entry,
            cover: widget.covers[entry.species.id],
            onTap: () => widget.onOpen(entry),
          );
        },
      );
    }
    final scaler = MediaQuery.textScalerOf(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          // As many columns as fit at most kSpeciesCardMaxWidth each, each
          // card as tall as its picture and text need at this text size.
          final width = constraints.crossAxisExtent;
          final columns = math.max(
            1,
            ((width + 8) / (kSpeciesCardMaxWidth + 8)).ceil(),
          );
          final cell = (width - 8 * (columns - 1)) / columns;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: speciesCardHeight(
                cell,
                scaler,
                withMarker:
                    widget.by == SpeciesGroupBy.trip ||
                    widget.by == SpeciesGroupBy.site,
              ),
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _card(
                entry,
                firstSeenHere: firstSeenHere.contains(entry.species.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _shelf(BuildContext context, SpeciesGroup group) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cardHeight = speciesCardHeight(
      kSpeciesShelfCardWidth,
      MediaQuery.textScalerOf(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_label(context, group)} · '
                  '${l10n.marineLife_speciesPage_speciesCount(group.entries.length)}',
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => widget.onSeeAllCategory(group.category!),
                child: Text(l10n.marineLife_speciesPage_seeAll),
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            key: PageStorageKey('species_shelf_${group.key}'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: group.entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => SizedBox(
              width: kSpeciesShelfCardWidth,
              child: _card(group.entries[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, SpeciesGroup group) {
    final expanded = !_collapsed.contains(group.key);
    final l10n = context.l10n;
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _SectionHeader(
            child: CollapsibleGroupHeader(
              key: ValueKey('species_section_${group.key}'),
              label: _label(context, group),
              countLabel: l10n.marineLife_speciesPage_speciesCount(
                group.entries.length,
              ),
              isExpanded: expanded,
              isHeading: true,
              onTap: () => setState(() {
                if (!_collapsed.remove(group.key)) _collapsed.add(group.key);
              }),
            ),
            color: Theme.of(context).colorScheme.surface,
            height: math.max(48, MediaQuery.textScalerOf(context).scale(56)),
          ),
        ),
        if (expanded) _entries(group.entries, group.firstSeenHere),
      ],
    );
  }
}

class _SectionHeader extends SliverPersistentHeaderDelegate {
  _SectionHeader({
    required this.child,
    required this.color,
    required this.height,
  });

  final Widget child;
  final Color color;

  /// Grows with the text size, so a large one is not clipped.
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: color,
    child: Align(alignment: AlignmentDirectional.centerStart, child: child),
  );

  @override
  bool shouldRebuild(_SectionHeader oldDelegate) =>
      oldDelegate.child != child ||
      oldDelegate.color != color ||
      oldDelegate.height != height;
}
