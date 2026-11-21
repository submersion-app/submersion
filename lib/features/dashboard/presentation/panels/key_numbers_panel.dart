import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
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
/// its own bordered box and tap target, sharing the rows they wrap into.
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

  /// The panel's height for [tileCount] tiles at [tier]: a short row per
  /// line of tiles.
  static double heightFor(
    BuildContext context,
    HomeWidthTier tier,
    int tileCount,
  ) {
    final count = tileCount < 1 ? 1 : tileCount;
    final perRow = tilesPerRow(tier, count);
    final rows = (count + perRow - 1) ~/ perRow;
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

    final List<Widget> tiles;
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
      tiles = [
        for (final t in HomeKeyNumber.values)
          if (enabled.contains(t) && n.has(t)) _tileFor(context, ref, t, n),
      ];
    }
    if (tiles.isEmpty) return const SizedBox.shrink();

    final perRow = tilesPerRow(tier, tiles.length);
    final rowHeight = homeRowHeight(HomePanelHeight.short, context);
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += perRow) ...[
          if (i > 0) const SizedBox(height: _gap),
          SizedBox(
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + perRow && j < tiles.length; j++) ...[
                  if (j > i) const SizedBox(width: _gap),
                  Expanded(child: tiles[j]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _tileFor(
    BuildContext context,
    WidgetRef ref,
    HomeKeyNumber tile,
    HomeKeyNumbers n,
  ) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    // One decimal, dropped when it is zero: 42.1 and 30, not 30.0.
    String depth(double m) {
      final v = units.convertDepth(m);
      final rounded = (v * 10).round() / 10;
      return rounded == rounded.roundToDouble()
          ? rounded.toStringAsFixed(0)
          : rounded.toStringAsFixed(1);
    }

    switch (tile) {
      case HomeKeyNumber.dives:
        return _Tile(
          title: l10n.dashboard_key_dives,
          value: '${n.careerDives}',
          unit: '',
          comparison: n.divesThisYear == null
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
          comparison: yearSeconds == null
              ? null
              : l10n.dashboard_key_hoursThisYear(_hours(yearSeconds)),
          semantics: '$hours ${l10n.dashboard_key_hoursUnit}',
          onTap: () => context.push('/insights'),
        );
      case HomeKeyNumber.lastDive:
        final days = n.daysSinceLastDive!;
        return _Tile(
          title: l10n.dashboard_key_lastDive,
          value: '$days',
          unit: l10n.dashboard_key_daysUnit(days),
          comparison: n.lastDiveSite,
          semantics: '$days ${l10n.dashboard_key_daysUnit(days)}',
          onTap: () => context.push('/dives/${n.lastDiveId}'),
        );
      case HomeKeyNumber.avgSac:
        final sac = n.sacLane == GasConsumptionLane.sac;
        final value = sac
            ? units.convertSac(n.avgSac!)
            : units.convertRmv(n.avgSac!);
        final change = n.avgSacChange;
        // Rounded before the sign is chosen, so a change too small to show
        // reads 0.0 rather than +0.0 or -0.0.
        final shownChange = change == null
            ? null
            : ((sac ? units.convertSac(change) : units.convertRmv(change)) * 10)
                      .round() /
                  10;
        final changeText = shownChange == null
            ? null
            : shownChange == 0
            ? 0.0.toStringAsFixed(1)
            : (shownChange > 0 ? '+' : '') + shownChange.toStringAsFixed(1);
        final unit = sac ? units.sacSymbol : units.rmvSymbol;
        return _Tile(
          title: sac ? l10n.dashboard_key_avgSac : l10n.dashboard_key_avgRmv,
          value: value.toStringAsFixed(1),
          unit: unit,
          comparison: changeText == null
              ? null
              : l10n.dashboard_key_vsPrevious(changeText),
          series: n.sacSeries,
          semantics: '${value.toStringAsFixed(1)} $unit',
          onTap: () => context.push('/insights'),
        );
      case HomeKeyNumber.deepestThisYear:
        return _Tile(
          title: l10n.dashboard_key_deepestThisYear,
          value: depth(n.deepestThisYear!),
          unit: units.depthSymbol,
          comparison: n.deepestLastYear == null
              ? null
              : l10n.dashboard_key_lastYear(
                  units.formatDepth(n.deepestLastYear),
                ),
          semantics: units.formatDepth(n.deepestThisYear),
          onTap: () => context.push('/insights'),
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
/// not "0", and whole hours from there.
String _hours(int seconds) {
  final exact = seconds / 3600;
  return exact < 10 ? exact.toStringAsFixed(1) : exact.floor().toString();
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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return HomePanel(
      title: title,
      semanticsValue: semantics,
      onTap: onTap,
      fit: HomePanelFit.clip,
      child:
          child ??
          Column(
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
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
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
              if (series != null && series!.length > 1) ...[
                const SizedBox(height: 3),
                SizedBox(height: 16, child: HomeSparkline(series!)),
              ],
            ],
          ),
    );
  }
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
