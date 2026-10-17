import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_summary_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_scene_markers.dart';
import 'package:submersion/features/insights/domain/career_totals.dart';
import 'package:submersion/features/insights/presentation/providers/career_totals_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/scenes/water_column_painter.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';
import 'package:submersion/shared/widgets/summary/summary_scene_pane.dart';

/// The Dives summary pane as a scene: the water column, with the log's
/// totals at the surface and its usual and deepest depths placed where they
/// happened.
///
/// It reads exactly what `DiveSummaryWidget` reads: career totals (logged
/// plus prior dives) with no dive list filter, the filtered dives alone
/// while one is active (#808, #1078).
class DiveSummaryScene extends ConsumerWidget {
  const DiveSummaryScene({super.key});

  /// Below this width the end column folds and the headline shrinks.
  static const double compactWidth = 560;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFiltered = ref.watch(diveFilterProvider).effective.hasActiveFilters;
    final units = UnitFormatter(ref.watch(settingsProvider));

    final statsAsync = ref.watch(
      isFiltered ? diveListScopedStatisticsProvider : diveStatisticsProvider,
    );
    final recordsAsync = ref.watch(
      isFiltered ? diveListScopedRecordsProvider : diveRecordsProvider,
    );
    final careerAsync = isFiltered ? null : ref.watch(careerTotalsProvider);
    // `.value`, not `valueOrNull`: a filter edit keeps the previous facts up
    // until the new query lands instead of blanking on every keystroke.
    final stats = statsAsync.value;
    final career = careerAsync?.value;
    final hasError =
        statsAsync.hasError && !statsAsync.hasValue ||
        (careerAsync?.hasError ?? false) && !(careerAsync?.hasValue ?? false);
    final ready = stats != null && (isFiltered || career != null);

    return SummaryScenePane(
      ink: Colors.white,
      shadows: const [Shadow(color: Color(0x55002840), blurRadius: 14)],
      painterBuilder: (seconds, brightness) =>
          WaterColumnPainter(seconds: seconds, brightness: brightness),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = w < compactWidth;
          final inset = w * 0.075;
          // The headline takes its natural height; the depth region fills
          // what is left below it, so markers can never ride up into the
          // headline on a short pane.
          return Padding(
            padding: EdgeInsets.only(top: h * 0.11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: inset,
                    end: compact ? inset : w * 0.24,
                  ),
                  child: _Headline(
                    stats: ready ? stats : null,
                    career: career,
                    isFiltered: isFiltered,
                    compact: compact,
                    showFacts: ready && !hasError,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ready && !hasError
                      ? LayoutBuilder(
                          builder: (context, region) => Stack(
                            children: _depthLayer(
                              context,
                              stats: stats,
                              records: recordsAsync.value,
                              units: units,
                              width: w,
                              height: region.maxHeight,
                              compact: compact,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _depthLayer(
    BuildContext context, {
    required DiveStatistics stats,
    required DiveRecords? records,
    required UnitFormatter units,
    required double width,
    required double height,
    required bool compact,
  }) {
    final l10n = context.l10n;
    final deepest = records?.deepestDive;
    final deepestDepth = deepest?.maxDepth;
    final usual = stats.avgMaxDepth > 0 ? stats.avgMaxDepth : null;
    if (usual == null && deepestDepth == null) return const [];

    final maxMeters = scaleMaxMeters(
      deepestDepth ?? usual!,
      units.settings.depthUnit,
    );
    final inset = width * 0.075;
    final markerEnd = inset + DepthScale.width;

    double topFor(double meters) =>
        (height * depthToFraction(meters, maxMeters) - DepthMarker.lineOffset)
            .clamp(0.0, double.infinity);

    final crowded =
        usual != null &&
        deepestDepth != null &&
        (depthToFraction(usual, maxMeters) -
                    depthToFraction(deepestDepth, maxMeters))
                .abs() <
            0.09;

    String deepestLabel(DiveRecord record) {
      final date = units.formatDate(record.dateTime);
      final site = record.siteName;
      return site == null || site.isEmpty
          ? l10n.diveLog_scene_deepestNoSite(date)
          : l10n.diveLog_scene_deepest(site, date);
    }

    return [
      PositionedDirectional(
        key: const ValueKey('scene-depth-scale'),
        end: inset,
        top: 0,
        bottom: 0,
        width: DepthScale.width,
        child: DepthScale(maxMeters: maxMeters, units: units),
      ),
      if (usual != null)
        PositionedDirectional(
          start: inset,
          end: markerEnd,
          top: topFor(usual),
          child: DepthMarker(
            value: units.formatDepth(usual),
            label: l10n.diveLog_scene_usualDepth,
            compact: crowded || compact,
          ),
        ),
      if (deepest != null && deepestDepth != null)
        PositionedDirectional(
          start: inset,
          end: markerEnd,
          top: topFor(deepestDepth),
          child: DepthMarker(
            value: units.formatDepth(deepestDepth),
            label: deepestLabel(deepest),
            compact: compact,
            onTap: () {
              final path = GoRouterState.of(context).uri.path;
              context.goInPlace('$path?selected=${deepest.diveId}');
            },
          ),
        ),
    ];
  }
}

/// The deepest depth the scale shows, in metres, chosen so its three ticks
/// (surface, one step, two steps) land on round numbers in the diver's unit
/// and the deepest dive fits above the scale's end.
double scaleMaxMeters(double deepestMeters, DepthUnit unit) {
  final steps = unit == DepthUnit.feet
      ? const [10.0, 25.0, 50.0, 100.0, 200.0, 250.0, 500.0]
      : const [5.0, 10.0, 20.0, 25.0, 50.0, 100.0, 200.0];
  final deepest = DepthUnit.meters.convert(deepestMeters, unit);
  final step = steps.firstWhere(
    (s) => s * 2.25 >= deepest,
    orElse: () => steps.last,
  );
  return unit.convert(step * 2.25, DepthUnit.meters);
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.stats,
    required this.career,
    required this.isFiltered,
    required this.compact,
    required this.showFacts,
  });

  final DiveStatistics? stats;
  final CareerTotals? career;
  final bool isFiltered;
  final bool compact;
  final bool showFacts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = this.stats;
    if (!showFacts || stats == null) {
      return SceneEyebrow(l10n.nav_dives);
    }
    final dives = career?.combinedDives ?? stats.totalDives;
    final seconds = career?.combinedTimeSeconds ?? stats.totalTimeSeconds;
    final sites = stats.topSites.isEmpty
        ? l10n.diveLog_scene_sitesNoTop(stats.totalSites)
        : l10n.diveLog_scene_sites(
            stats.totalSites,
            stats.topSites.first.siteName,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SceneEyebrow(l10n.nav_dives),
        const SizedBox(height: 6),
        SceneHeadline(
          l10n.diveLog_scene_headline(dives, formatHoursMinutes(seconds)),
          compact: compact,
        ),
        const SizedBox(height: 6),
        SceneSentence(sites),
        if (isFiltered) const _FilteredLine(),
      ],
    );
  }
}

/// While the dive list is filtered, says how many dives the scene covers.
class _FilteredLine extends ConsumerWidget {
  const _FilteredLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(diveListScopedStatisticsProvider).value;
    final total = ref.watch(diveStatisticsProvider).value;
    if (shown == null || total == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SceneLabel(
        context.l10n.diveLog_summary_filteredBanner(
          shown.totalDives,
          total.totalDives,
        ),
      ),
    );
  }
}

/// "61h 20m", or "20m" under an hour: the summary widget's own format.
String formatHoursMinutes(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}
