import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:clock/clock.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const double _gap = 8;

/// The row of headline numbers at the top of Home: up to eight tiles, each
/// its own filled box and tap target, sharing the rows they wrap into.
class KeyNumbersPanel extends ConsumerWidget {
  const KeyNumbersPanel({super.key});

  /// Tiles in a row: all on desktop; on a tablet all up to four, otherwise
  /// half (rounded up) so the rows come out even; two on a phone.
  static int tilesPerRow(HomeWidthTier tier, int tileCount) => switch (tier) {
    HomeWidthTier.desktop => tileCount < 1 ? 1 : tileCount,
    HomeWidthTier.tablet => tileCount <= 4 ? tileCount : (tileCount + 1) ~/ 2,
    HomeWidthTier.phone => 2,
  };

  /// The tiles this diver has on, from their hidden set (null: the default).
  static Set<HomeKeyNumber> enabledTiles(Set<String>? hidden) {
    final off = hidden ?? defaultHiddenKeyNumbers.map((t) => t.name).toSet();
    return {
      for (final t in HomeKeyNumber.values)
        if (!off.contains(t.name)) t,
    };
  }

  /// How many tiles show: enabled and with something to say. While the
  /// numbers load every enabled tile holds a placeholder.
  static int visibleTileCount(HomeKeyNumbers? numbers, Set<String>? hidden) {
    final enabled = enabledTiles(hidden);
    if (numbers == null) return enabled.length;
    return enabled.where(numbers.has).length;
  }

  /// Whether the first tile takes a row of its own as a headline: on a
  /// phone, where tiles pair up, an odd count would otherwise leave the last
  /// tile alone on a half-empty row.
  static bool headlineFirst(HomeWidthTier tier, int tileCount) =>
      tier == HomeWidthTier.phone && tileCount.isOdd;

  /// The panel's height for [tileCount] tiles at [tier]: a short row per
  /// line of tiles.
  static double heightFor(
    BuildContext context,
    HomeWidthTier tier,
    int tileCount,
  ) {
    final count = tileCount < 1 ? 1 : tileCount;
    final perRow = tilesPerRow(tier, count);
    final rows = headlineFirst(tier, count)
        ? 1 + (count - 1) ~/ perRow
        : (count + perRow - 1) ~/ perRow;
    return rows * homeRowHeight(HomePanelHeight.short, context) +
        (rows - 1) * _gap;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      settingsProvider.select((s) => s.hiddenHomeKeyNumbers),
    );
    final numbers = ref.watch(homeKeyNumbersProvider);
    final enabled = enabledTiles(hidden);
    final tier = homeWidthTierOf(context);

    final List<_Tile> tiles;
    final n = numbers.value;
    if (n == null) {
      tiles = [
        for (final _ in enabled)
          _Tile(
            title: '',
            value: '',
            unit: '',
            semantics: '',
            child: numbers.hasError
                ? Text(context.l10n.dashboard_panel_loadError)
                : const SizedBox(),
          ),
      ];
    } else {
      final shown = [
        for (final t in HomeKeyNumber.values)
          if (enabled.contains(t) && n.has(t)) t,
      ];
      final headline = headlineFirst(tier, shown.length);
      final now = clock.now();
      tiles = [
        for (var i = 0; i < shown.length; i++)
          headline && i == 0
              ? _tileFor(context, ref, shown[i], n).headlined(
                  // The dives line is the last twelve months; say where it
                  // starts. Other series carry no dates.
                  lineStart: shown[i] == HomeKeyNumber.dives
                      ? ref
                            .watch(unitFormatterProvider)
                            .formatMonthYear(DateTime(now.year, now.month - 11))
                      : null,
                )
              : _tileFor(context, ref, shown[i], n),
      ];
    }
    if (tiles.isEmpty) return const SizedBox.shrink();

    final perRow = tilesPerRow(tier, tiles.length);
    final rowHeight = homeRowHeight(HomePanelHeight.short, context);
    final rows = <List<Widget>>[
      if (tiles.first.headline) [tiles.first],
      for (var i = tiles.first.headline ? 1 : 0; i < tiles.length; i += perRow)
        tiles.sublist(i, math.min(i + perRow, tiles.length)),
    ];
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: _gap),
          SizedBox(
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < rows[r].length; j++) ...[
                  if (j > 0) const SizedBox(width: _gap),
                  Expanded(child: rows[r][j]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  _Tile _tileFor(
    BuildContext context,
    WidgetRef ref,
    HomeKeyNumber tile,
    HomeKeyNumbers n,
  ) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    // One decimal, dropped when it is zero: 42.1 and 30, not 30.0. In the
    // locale's own decimal separator, as the comparison lines are.
    String depth(double m) {
      final v = units.convertDepth(m);
      final rounded = (v * 10).round() / 10;
      return formatFixedForDisplay(
        rounded,
        rounded == rounded.roundToDouble() ? 0 : 1,
      );
    }

    switch (tile) {
      case HomeKeyNumber.dives:
        return _Tile(
          title: l10n.dashboard_key_dives,
          value: '${n.careerDives}',
          unit: '',
          // Nothing logged yet this year says nothing, as with species: a
          // "+0" in the accent colour would read as growth.
          comparison: (n.divesThisYear ?? 0) == 0
              ? null
              : l10n.dashboard_key_countThisYear(n.divesThisYear!),
          highlight: true,
          series: n.monthlySeries,
          semantics: '${n.careerDives}',
          onTap: () => context.push('/dives'),
        );
      case HomeKeyNumber.timeUnder:
        final hours = _hours(n.careerTimeSeconds);
        final yearSeconds = n.timeThisYearSeconds;
        return _Tile(
          title: l10n.dashboard_key_timeUnder,
          value: hours,
          highlight: true,
          unit: l10n.dashboard_key_hoursUnit,
          comparison: (yearSeconds ?? 0) == 0
              ? null
              : l10n.dashboard_key_hoursThisYear(_hours(yearSeconds!)),
          semantics: '$hours ${l10n.dashboard_key_hoursUnit}',
          onTap: () => context.push('/dives'),
        );
      case HomeKeyNumber.lastDive:
        final days = n.daysSinceLastDive!;
        final lastDate = n.lastDiveDate;
        // Its site and date; either may be missing.
        final where = [
          n.lastDiveSite?.trim() ?? '',
          if (lastDate != null) units.formatDate(lastDate),
        ].where((part) => part.isNotEmpty).join(' · ');
        return _Tile(
          title: l10n.dashboard_key_lastDive,
          value: '$days',
          unit: l10n.dashboard_key_daysUnit(days),
          comparison: where.isEmpty ? null : where,
          semantics: '$days ${l10n.dashboard_key_daysUnit(days)}',
          onTap: () => context.push('/dives/${n.lastDiveId}'),
        );
      case HomeKeyNumber.avgSac:
        final sac = n.sacLane == GasConsumptionLane.sac;
        double convert(double v) =>
            sac ? units.convertSac(v) : units.convertRmv(v);
        // The unit's own precision, as everywhere else SAC and RMV show:
        // whole psi a minute, and two places for cuft a minute, whose values
        // sit below one.
        final decimals = sac ? units.sacDecimals : units.rmvDecimals;
        final value = formatFixedForDisplay(convert(n.avgSac!), decimals);
        final change = n.avgSacChange;
        // Rounded before the sign is chosen, so a change too small to show
        // reads 0.0 rather than +0.0 or -0.0.
        final scale = math.pow(10, decimals);
        final shownChange = change == null
            ? null
            : (convert(change) * scale).round() / scale;
        final changeText = shownChange == null
            ? null
            : shownChange == 0
            ? formatFixedForDisplay(0, decimals)
            : (shownChange > 0 ? '+' : '') +
                  formatFixedForDisplay(shownChange, decimals);
        final unit = sac ? units.sacSymbol : units.rmvSymbol;
        return _Tile(
          title: sac ? l10n.dashboard_key_avgSac : l10n.dashboard_key_avgRmv,
          value: value,
          unit: unit,
          comparison: changeText == null
              ? null
              : l10n.dashboard_key_vsPrevious(changeText),
          series: n.sacSeries,
          semantics: '$value $unit',
          onTap: () => context.push('/insights'),
        );
      case HomeKeyNumber.deepestThisYear:
        final deepestId = n.deepestDiveId;
        return _Tile(
          title: l10n.dashboard_key_deepestThisYear,
          value: depth(n.deepestThisYear!),
          unit: units.depthSymbol,
          // The dive's site; last year's deepest when it has neither a site
          // nor a name.
          comparison:
              n.deepestDiveSite ??
              (n.deepestLastYear == null
                  ? null
                  : l10n.dashboard_key_lastYear(
                      units.formatDepth(n.deepestLastYear),
                    )),
          semantics: units.formatDepth(n.deepestThisYear),
          onTap: () => context.push(
            deepestId == null ? '/insights' : '/dives/$deepestId',
          ),
        );
      case HomeKeyNumber.nextTrip:
        final trip = n.nextTrip!;
        final tripDays = trip.daysUntilStart;
        return _Tile(
          title: l10n.dashboard_key_nextTrip,
          value: '$tripDays',
          unit: l10n.dashboard_key_daysUnit(tripDays),
          comparison: n.tripChecklistTotal == null
              ? trip.name
              : l10n.dashboard_key_tripChecklist(
                  trip.name,
                  n.tripChecklistDone!,
                  n.tripChecklistTotal!,
                ),
          semantics:
              '${trip.name}, $tripDays ${l10n.dashboard_key_daysUnit(tripDays)}',
          onTap: () => context.push('/trips/${trip.id}'),
        );
      case HomeKeyNumber.avgDepth:
        return _Tile(
          title: l10n.dashboard_key_avgDepth,
          value: depth(n.avgDepthThisYear!),
          unit: units.depthSymbol,
          comparison: n.avgDepthLastYear == null
              ? null
              : l10n.dashboard_key_lastYear(
                  units.formatDepth(n.avgDepthLastYear),
                ),
          semantics: units.formatDepth(n.avgDepthThisYear),
          onTap: () => context.push('/insights'),
        );
      case HomeKeyNumber.species:
        return _Tile(
          title: l10n.dashboard_key_species,
          value: '${n.species}',
          unit: '',
          comparison: (n.newSpeciesThisYear ?? 0) == 0
              ? null
              : l10n.dashboard_key_countThisYear(n.newSpeciesThisYear!),
          highlight: true,
          semantics: '${n.species}',
          onTap: () => context.push('/species'),
        );
    }
  }
}

/// Hours from [seconds]: a decimal under ten, so a first 45-minute dive is
/// not "0", and whole hours from there. The choice is made on the value as
/// rounded for display, so 9.97 hours reads "10", not "10.0". In the
/// locale's decimal separator.
String _hours(int seconds) {
  final exact = seconds / 3600;
  final tenths = (exact * 10).round() / 10;
  // Whole hours count down (10.9 is "10"), but never below the ten the
  // rounding reached.
  return tenths < 10
      ? formatFixedForDisplay(tenths, 1)
      : math.max(10, exact.floor()).toString();
}

/// One number tile: title, value with its unit, a comparison line, and a
/// small trend line when there is a series.
class _Tile extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String? comparison;
  final List<double>? series;
  final String semantics;

  /// Draws the comparison in the accent colour: for counts that grew this
  /// year, never for a change whose sign means better or worse.
  final bool highlight;
  final VoidCallback? onTap;
  final Widget? child;

  /// A full-row tile: a larger value, with the trend line beside it.
  final bool headline;

  /// Where a headline's trend line starts, shown under it with "now".
  final String? lineStart;

  const _Tile({
    required this.title,
    required this.value,
    required this.unit,
    required this.semantics,
    this.comparison,
    this.series,
    this.onTap,
    this.child,
    this.highlight = false,
    this.headline = false,
    this.lineStart,
  });

  _Tile headlined({String? lineStart}) => _Tile(
    title: title,
    value: value,
    unit: unit,
    semantics: semantics,
    comparison: comparison,
    series: series,
    onTap: onTap,
    highlight: highlight,
    headline: true,
    lineStart: lineStart,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: value),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (headline
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge)
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
        ),
        if (comparison != null)
          Text(
            comparison!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: highlight ? theme.colorScheme.primary : muted,
            ),
          ),
      ],
    );
    final hasLine = child == null && series != null && series!.length > 1;

    return HomePanel(
      title: title,
      semanticsValue: semantics,
      onTap: onTap,
      // A tile with a trend line fills its box, so the line can take the
      // height its text leaves; the rest let taller text be clipped.
      fit: hasLine ? HomePanelFit.fill : HomePanelFit.clip,
      child:
          child ??
          (hasLine && headline
              ? CustomMultiChildLayout(
                  delegate: _TextBesideLine(Directionality.of(context)),
                  children: [
                    LayoutId(id: _TextBesideLine.text, child: text),
                    LayoutId(
                      id: _TextBesideLine.line,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: HomeSparkline(series!)),
                          if (lineStart != null)
                            // The line runs oldest to newest left to right in
                            // every language, so its labels do too.
                            DefaultTextStyle.merge(
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: muted,
                              ),
                              maxLines: 1,
                              child: Row(
                                textDirection: TextDirection.ltr,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      lineStart!,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.l10n.dashboard_key_now,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              : hasLine
              ? CustomMultiChildLayout(
                  delegate: _TextThenLine(),
                  children: [
                    LayoutId(id: _TextThenLine.text, child: text),
                    LayoutId(
                      id: _TextThenLine.line,
                      child: HomeSparkline(series!),
                    ),
                  ],
                )
              : text),
    );
  }
}

/// Lays a headline's text out at its own size on the left, at most half the
/// width, and gives its trend line the rest of the row beside it. The line is
/// not shown when less than [minWidth] is left.
class _TextBesideLine extends MultiChildLayoutDelegate {
  /// Puts the text on the reading side: the left, or the right in a
  /// right-to-left language, as the panel title above it is.
  final TextDirection direction;

  _TextBesideLine(this.direction);

  static const text = 'text';
  static const line = 'line';
  static const double gap = 14;
  static const double minWidth = 40;

  @override
  void performLayout(Size size) {
    final textSize = layoutChild(
      text,
      BoxConstraints(maxWidth: size.width / 2),
    );
    final rtl = direction == TextDirection.rtl;
    final top = math.max(0.0, size.height - textSize.height);
    positionChild(text, Offset(rtl ? size.width - textSize.width : 0, top));
    final width = size.width - textSize.width - gap;
    layoutChild(
      line,
      BoxConstraints.tight(
        width >= minWidth ? Size(width, size.height) : Size.zero,
      ),
    );
    positionChild(line, Offset(rtl ? 0 : textSize.width + gap, 0));
  }

  @override
  bool shouldRelayout(_TextBesideLine oldDelegate) =>
      oldDelegate.direction != direction;
}

/// Lays a tile's text out at its own height, then gives the trend line the
/// height left under it, at most [maxLine], so the line is never drawn
/// below the tile's clipped content. With less than [minLine] left the line
/// is not shown.
class _TextThenLine extends MultiChildLayoutDelegate {
  static const text = 'text';
  static const line = 'line';
  static const double gap = 3;
  static const double maxLine = 16;
  static const double minLine = 4;

  @override
  void performLayout(Size size) {
    final textSize = layoutChild(text, BoxConstraints(maxWidth: size.width));
    positionChild(text, Offset.zero);
    final room = size.height - textSize.height - gap;
    final height = room >= minLine ? math.min(room, maxLine) : 0.0;
    layoutChild(line, BoxConstraints.tight(Size(size.width, height)));
    positionChild(line, Offset(0, textSize.height + gap));
  }

  @override
  bool shouldRelayout(_TextThenLine oldDelegate) => false;
}

/// Exposed for the settings sub-page: a tile's name in the diver's language.
/// The gas tile takes the name Home shows it by, from the diver's [lane].
String homeKeyNumberLabel(
  AppLocalizations l10n,
  HomeKeyNumber tile, {
  required GasConsumptionLane lane,
}) => switch (tile) {
  HomeKeyNumber.dives => l10n.dashboard_key_dives,
  HomeKeyNumber.timeUnder => l10n.dashboard_key_timeUnder,
  HomeKeyNumber.lastDive => l10n.dashboard_key_lastDive,
  HomeKeyNumber.avgSac =>
    lane == GasConsumptionLane.sac
        ? l10n.dashboard_key_avgSac
        : l10n.dashboard_key_avgRmv,
  HomeKeyNumber.deepestThisYear => l10n.dashboard_key_deepestThisYear,
  HomeKeyNumber.nextTrip => l10n.dashboard_key_nextTrip,
  HomeKeyNumber.avgDepth => l10n.dashboard_key_avgDepth,
  HomeKeyNumber.species => l10n.dashboard_key_species,
};
