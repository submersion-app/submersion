import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_scene_facts.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/scenes/chart_marks_painter.dart';
import 'package:submersion/shared/widgets/scenes/chart_painter.dart';
import 'package:submersion/shared/widgets/summary/chart_marks_layer.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';
import 'package:submersion/shared/widgets/summary/summary_scene_pane.dart';

/// The Trips summary pane as a scene: the passage, the paper chart with a
/// dashed course from Home through the last trip to the next one.
///
/// It reads exactly what `TripSummaryWidget` reads. Trips carry no country
/// and the marks sit at fixed places: the chart is a drawing, not a map.
class TripSummaryScene extends ConsumerWidget {
  const TripSummaryScene({super.key});

  /// Below this width the headline shrinks and mark labels shorten.
  static const double compactWidth = 560;

  /// Where Home, the last trip and the next trip sit, as fractions of the
  /// region below the headline.
  static const home = ChartSpot(at: Offset(0.19, 0.80), halo: false);
  static const lastSpot = ChartSpot(at: Offset(0.52, 0.56));
  static const nextSpot = ChartSpot(at: Offset(0.77, 0.26), haloDelay: -4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListNotifierProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final trips = tripsAsync.hasError ? null : tripsAsync.value;
    final facts = trips == null
        ? null
        : TripSceneFacts.from(trips, clock.now());
    final palette = ChartPalette.of(Theme.of(context).brightness);

    return SummaryScenePane(
      ink: palette.ink,
      shadows: palette.inkShadows,
      painterBuilder: (seconds, brightness) =>
          ChartPainter(seconds: seconds, brightness: brightness),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = w < compactWidth;
          final inset = w * 0.075;
          final footer = facts == null ? null : _footer(context, facts);
          return Padding(
            padding: EdgeInsets.only(top: h * 0.11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: inset,
                    end: compact ? inset : w * 0.30,
                  ),
                  child: _headline(
                    context,
                    facts,
                    units,
                    compact: compact,
                    sentenceWidth: compact ? w - 2 * inset : 520,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: facts == null || facts.tripCount == 0
                      ? const SizedBox.shrink()
                      : ChartMarksLayer(
                          course: true,
                          compact: compact,
                          marks: _marks(context, facts, units),
                        ),
                ),
                if (footer != null)
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      inset,
                      8,
                      inset,
                      h * 0.09,
                    ),
                    child: SceneFooter(footer),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headline(
    BuildContext context,
    TripSceneFacts? facts,
    UnitFormatter units, {
    required bool compact,
    required double sentenceWidth,
  }) {
    final l10n = context.l10n;
    final eyebrow = SceneEyebrow(l10n.nav_trips);
    if (facts == null) return eyebrow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        eyebrow,
        const SizedBox(height: 6),
        SceneHeadline(
          l10n.trips_scene_headline(facts.tripCount, facts.totalDays),
          compact: compact,
        ),
        // No trips, no passage: the pane only shows a scene for an empty
        // list when the diver flips the toggle.
        if (facts.tripCount > 0) ...[
          const SizedBox(height: 6),
          SceneSentence(
            _sentence(context, facts, units),
            maxWidth: sentenceWidth,
          ),
        ],
      ],
    );
  }

  String _sentence(
    BuildContext context,
    TripSceneFacts facts,
    UnitFormatter units,
  ) {
    final l10n = context.l10n;
    final next = facts.next;
    final last = facts.last;
    if (next != null && last != null) {
      return l10n.trips_scene_sentence(
        next.trip.name,
        _countdown(context, next),
        last.trip.name,
        units.formatMonthYear(last.trip.startDate),
      );
    }
    if (next != null) {
      return l10n.trips_scene_sentenceNextOnly(
        next.trip.name,
        _countdown(context, next),
      );
    }
    return l10n.trips_scene_sentenceLastOnly(
      last!.trip.name,
      units.formatMonthYear(last.trip.startDate),
    );
  }

  /// The details view's own countdown wording ("In 23 days").
  String _countdown(BuildContext context, TripWithStats trip) =>
      context.l10n.trips_list_countdown(trip.trip.daysUntilStart);

  List<ChartMark> _marks(
    BuildContext context,
    TripSceneFacts facts,
    UnitFormatter units,
  ) {
    final l10n = context.l10n;
    ChartMark tripMark(ChartSpot spot, TripWithStats trip, String when) =>
        ChartMark(
          spot: spot,
          label: l10n.trips_scene_mark(trip.trip.name, when),
          compactLabel: trip.trip.name,
          onTap: () {
            final path = GoRouterState.of(context).uri.path;
            context.goInPlace('$path?selected=${trip.trip.id}');
          },
        );
    final last = facts.last;
    final next = facts.next;
    return [
      ChartMark(spot: home, label: l10n.trips_scene_home),
      if (last != null)
        tripMark(lastSpot, last, units.formatMonthYear(last.trip.startDate)),
      if (next != null) tripMark(nextSpot, next, _countdown(context, next)),
    ];
  }

  String? _footer(BuildContext context, TripSceneFacts facts) {
    final l10n = context.l10n;
    final parts = [
      if (facts.liveaboards > 0)
        l10n.trips_scene_liveaboards(facts.liveaboards),
      if (facts.totalDives > 0) l10n.trips_scene_divesAway(facts.totalDives),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
