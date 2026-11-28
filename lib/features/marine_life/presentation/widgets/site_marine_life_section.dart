import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_tier_header.dart';
import 'package:submersion/features/reef/presentation/widgets/nearby_species_tier.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// The marine life at a dive site, shown only: the site page's Marine life
/// card, whose pencil edits the expected species in a sitting (issue #4527,
/// phase 2), the one way to change them.
class SiteMarineLifeSection extends ConsumerWidget {
  final String siteId;

  /// When present, a "Recorded nearby" tier is shown from online sources.
  final GeoPoint? location;

  /// The expected species to show in place of those stored: a sitting's,
  /// once the diver has changed them (issue #4527).
  final List<SiteSpeciesEntry>? species;

  const SiteMarineLifeSection({
    super.key,
    required this.siteId,
    this.location,
    this.species,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spottedAsync = ref.watch(siteSpottedSpeciesProvider(siteId));
    final held = species;
    final expectedAsync = held != null
        ? AsyncValue.data(held)
        : ref.watch(siteExpectedSpeciesProvider(siteId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildSpottedSection(context, ref, spottedAsync),
            _sectionDivider,
            _buildExpectedSection(context, ref, expectedAsync),
            if (location != null)
              // Shown only, as on the species map: a species opens its
              // page, and adding one is the unlocked card's (plan 7). The
              // divider comes with the tier's header, since the tier alone
              // knows whether it draws anything.
              NearbySpeciesTier(
                siteId: siteId,
                location: location!,
                onSpeciesTap: (id) => context.push('/species/$id'),
                headerBuilder: (context, count) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionDivider,
                    SpeciesTierHeader(
                      icon: Icons.travel_explore,
                      title: context.l10n.reef_species_recordedNearby,
                      count: count,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// What separates one section of the card from the next.
  static const Widget _sectionDivider = Divider(height: 32);

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // The pencil, while the page is unlocked (issue #4527).
    return RecordCardHeader(
      title: context.l10n.marineLife_siteSection_title,
      leading: Icon(Icons.water, size: 20, color: colorScheme.primary),
    );
  }

  Widget _buildSpottedSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SiteSpeciesSummary>> spottedAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpeciesTierHeader(
          icon: Icons.visibility,
          title: context.l10n.marineLife_siteSection_spottedHere,
          count: spottedAsync.value?.length,
        ),
        const SizedBox(height: 8),
        spottedAsync.when(
          data: (spotted) {
            if (spotted.isEmpty) {
              return Text(
                context.l10n.marineLife_siteSection_noSpotted,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              );
            }
            return _buildSpeciesChips(
              context,
              spotted
                  .map(
                    (s) => _SpeciesChipData(
                      id: s.speciesId,
                      name: localizedSpeciesName(
                        context.l10n,
                        s.speciesId,
                        s.speciesName,
                      ),
                      category: s.category,
                      count: s.sightingCount,
                    ),
                  )
                  .toList(),
              showCount: true,
            );
          },
          loading: () => const SizedBox(
            height: 32,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text(
            context.l10n.marineLife_siteSection_errorLoadingSightings,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildExpectedSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SiteSpeciesEntry>> expectedAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpeciesTierHeader(
          icon: Icons.auto_awesome,
          title: context.l10n.marineLife_siteSection_expectedSpecies,
          count: expectedAsync.value?.length,
        ),
        const SizedBox(height: 8),
        expectedAsync.when(
          data: (expected) {
            if (expected.isEmpty) {
              return Text(
                context.l10n.marineLife_siteSection_noExpected,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              );
            }
            return _buildSpeciesChips(
              context,
              expected
                  .map(
                    (s) => _SpeciesChipData(
                      id: s.speciesId,
                      name: localizedSpeciesName(
                        context.l10n,
                        s.speciesId,
                        s.speciesName,
                      ),
                      category: s.category,
                    ),
                  )
                  .toList(),
              showCount: false,
            );
          },
          loading: () => const SizedBox(
            height: 32,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text(
            context.l10n.marineLife_siteSection_errorLoadingExpected,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      ],
    );
  }

  /// The species grouped by category, each category's name in a column
  /// beside its chips (issue #5128). Stacked above them, the names ran
  /// together with the section titles, and a category of one species took
  /// two lines. The names sit on the baseline of their first row of chips.
  Widget _buildSpeciesChips(
    BuildContext context,
    List<_SpeciesChipData> species, {
    required bool showCount,
  }) {
    final grouped = <SpeciesCategory, List<_SpeciesChipData>>{};
    for (final s in species) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }

    final groups = grouped.entries.toList();

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
                    for (final s in entry.value)
                      _speciesChip(context, s, showCount: showCount),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Between a category's name and its chips.
  static const double _categoryGap = 12;

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

  Widget _speciesChip(
    BuildContext context,
    _SpeciesChipData s, {
    required bool showCount,
  }) {
    final theme = Theme.of(context);
    final count = showCount ? s.count : null;
    return Semantics(
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

class _SpeciesChipData {
  final String id;
  final String name;
  final SpeciesCategory category;
  final int? count;

  _SpeciesChipData({
    required this.id,
    required this.name,
    required this.category,
    this.count,
  });
}
