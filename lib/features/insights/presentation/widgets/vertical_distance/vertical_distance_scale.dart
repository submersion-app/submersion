import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_scale_layout.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_selection.dart';
import 'package:submersion/features/insights/presentation/formatters/vertical_landmark_labels.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_strip.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_scale_geometry.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_scale_painter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

export 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_scale_geometry.dart'
    show kVerticalScaleHeight, kVerticalScaleHalfHeight;

/// Widest the scale grows; on a wide screen it is centred, not stretched.
const double _maxScaleWidth = 440;

/// Height reserved for the estimated-dives note under the strip.
const double kVerticalNoteHeight = 16;

/// The scale and the strip with the gap between them: the body height of a
/// card with no note row, which its loading state reserves too.
const double kVerticalScaleAndStripHeight =
    kVerticalScaleHeight + 8 + kVerticalStripHeight;

/// The scale, the strip and the note with their gaps: the card's body
/// height, which its loading state reserves too.
const double kVerticalCardBodyHeight =
    kVerticalScaleAndStripHeight + 8 + kVerticalNoteHeight;

/// The vertical scale and its readout strip (issue #4569).
///
/// Pointing at a bar selects a level: hovering follows the pointer, a click
/// or a tap pins it, and press-and-hold then drag scrubs along the bar. A
/// tap anywhere else on the card unpins. No drag recognizer is attached, so
/// an ordinary swipe always reaches the page's scroll view.
///
/// The selection lives in a [ValueNotifier] that only the painter's hairline
/// and the strip listen to, so a pointer move repaints those two and never
/// rebuilds the labels, headlines or semantics.
class VerticalDistanceScale extends ConsumerStatefulWidget {
  const VerticalDistanceScale({
    super.key,
    required this.timeline,
    this.reservesNote = true,
    this.extentMeters,
  });

  final VerticalDistanceTimeline timeline;

  /// A larger height to size the scale to, shared with another card so the
  /// two sets of bars compare at a glance; null for the timeline's own. See
  /// [VerticalScaleLayout.compute].
  final double? extentMeters;

  /// Whether the estimated-dives note keeps its row under the strip while it
  /// has nothing to say. False for a timeline that can never estimate a
  /// dive, which would only leave the row blank; a note is shown either way
  /// when there is one.
  final bool reservesNote;

  @override
  ConsumerState<VerticalDistanceScale> createState() =>
      _VerticalDistanceScaleState();
}

class _VerticalDistanceScaleState extends ConsumerState<VerticalDistanceScale> {
  final _selection = ValueNotifier<VerticalSelection>(const VerticalIdle());
  late VerticalScaleLayout _layout = _layoutFor(widget);

  static VerticalScaleLayout _layoutFor(VerticalDistanceScale w) =>
      VerticalScaleLayout.compute(
        totalMeters: w.timeline.totalMeters,
        halfHeightPx: kVerticalScaleHalfHeight,
        extentMeters: w.extentMeters,
      );

  @override
  void didUpdateWidget(VerticalDistanceScale old) {
    super.didUpdateWidget(old);
    if (old.timeline != widget.timeline ||
        old.extentMeters != widget.extentMeters) {
      _layout = _layoutFor(widget);
      // A refresh with the same total (any Insights table write refreshes
      // the provider) keeps the selected level; the strip reads its date
      // from the new timeline. A different total redraws the scale, so the
      // old level means nothing there. A new shared extent only rescales:
      // the level is held in metres, so it stays.
      if (old.timeline.totalMeters != widget.timeline.totalMeters) {
        _selection.value = const VerticalIdle();
      }
    }
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  /// The landmark the dashed mark on [d]'s side shows, as the layout chose
  /// it, so the headline and semantics always name the one drawn.
  VerticalLandmark _next(VerticalLeg d) => _layout.marksOn(d).last.landmark;

  void _set(VerticalSelection next) {
    if (!identical(next, _selection.value)) _selection.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);
    final l10n = context.l10n;
    final timeline = widget.timeline;

    // Taps the scale or a button claim first; any other tap on the card
    // reaches this and unpins.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (_) => _set(tapSelection(_selection.value, null)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Center(
              child: _scale(
                context,
                units,
                math.min(constraints.maxWidth, _maxScaleWidth),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<VerticalSelection>(
            valueListenable: _selection,
            builder: (context, selection, _) {
              final probe = selection.probe;
              final crossing = probe == null || probe.ahead
                  ? null
                  : timeline.crossingAt(probe.meters);
              return VerticalDistanceStrip(
                key: const Key('verticalStrip'),
                text: _stripText(l10n, units, probe, crossing),
                selected: probe != null,
                pinned: selection is VerticalPinned,
                onOpen: crossing == null
                    ? null
                    : () => context.push('/dives/${crossing.diveId}'),
              );
            },
          ),
          // Where the card reserves the note's line, the card is the same
          // height with or without it, and while loading. A note to show is
          // always shown, reserved or not.
          if (widget.reservesNote || timeline.estimatedDives > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kVerticalNoteHeight,
                ),
                child: timeline.estimatedDives == 0
                    ? null
                    : Text(
                        l10n.insights_profile_verticalDistance_estimated(
                          timeline.estimatedDives,
                          timeline.countedDives,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scale(BuildContext context, UnitFormatter units, double width) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final g = VerticalScaleGeometry(
      width: width,
      layout: _layout,
      labelsOnLeft: !rtl,
    );
    final l10n = context.l10n;
    final total = widget.timeline.totalMeters;

    final visuals = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: VerticalScalePainter(
              geometry: g,
              selection: _selection,
              ascentColor: Colors.green,
              descentColor: Colors.blue,
              lineColor: theme.colorScheme.outline,
              hairlineColor: theme.colorScheme.onSurface,
            ),
          ),
        ),
        for (final d in VerticalLeg.values)
          for (final m in _layout.marksOn(d))
            if (m.labelled) _label(context, units, g, d, m),
        PositionedDirectional(
          top: g.seaY - 16,
          end: 0,
          child: Text(
            l10n.insights_profile_verticalDistance_seaLevel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _headline(context, units, g, VerticalLeg.ascent),
        _headline(context, units, g, VerticalLeg.descent),
      ],
    );

    final nextUp = _next(VerticalLeg.ascent);
    final nextDown = _next(VerticalLeg.descent);
    return SizedBox(
      key: const Key('verticalScale'),
      width: width,
      height: kVerticalScaleHeight,
      child: MouseRegion(
        onHover: (e) =>
            _set(hoverSelection(_selection.value, g.probeAt(e.localPosition))),
        onExit: (_) => _set(exitSelection(_selection.value)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) =>
              _set(tapSelection(_selection.value, g.probeAt(e.localPosition))),
          onLongPressStart: (e) =>
              _set(tapSelection(_selection.value, g.probeAt(e.localPosition))),
          // A scrub reads the bar's height only, so a thumb drifting off the
          // bar sideways keeps scrubbing instead of freezing or jumping to a
          // label.
          onLongPressMoveUpdate: (e) {
            final p = g.levelAt(e.localPosition.dy);
            if (p != null) _set(tapSelection(_selection.value, p));
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  container: true,
                  label: l10n.insights_profile_verticalDistance_semantics(
                    units.formatDepthWhole(total),
                    verticalLandmarkName(l10n, nextUp),
                    units.formatDepthWhole(
                      nextUp.meters - total,
                      roundUp: true,
                    ),
                    verticalLandmarkName(l10n, nextDown),
                    units.formatDepthWhole(
                      nextDown.meters - total,
                      roundUp: true,
                    ),
                  ),
                  child: ExcludeSemantics(child: visuals),
                ),
              ),
              ..._passedNodes(context, units, g),
            ],
          ),
        ),
      ),
    );
  }

  /// One semantics node per passed landmark, laid over its tick with no
  /// visible content, so the dates are reachable without a pointer.
  List<Widget> _passedNodes(
    BuildContext context,
    UnitFormatter units,
    VerticalScaleGeometry g,
  ) {
    final l10n = context.l10n;
    return [
      for (final d in VerticalLeg.values)
        for (final m in _layout.marksOn(d))
          if (m.passed)
            if (widget.timeline.crossingAt(m.landmark.meters) case final dive?)
              Positioned(
                left: g.barLeft,
                width: VerticalScaleGeometry.barWidth,
                top: g.yFor(d, m.offsetPx) - 1,
                height: 2,
                child: Semantics(
                  button: true,
                  label: l10n.insights_profile_verticalDistance_stripPassed(
                    verticalLandmarkName(l10n, m.landmark),
                    _date(units, dive),
                  ),
                  onTap: () => context.push('/dives/${dive.diveId}'),
                  child: const SizedBox.expand(),
                ),
              ),
    ];
  }

  Widget _label(
    BuildContext context,
    UnitFormatter units,
    VerticalScaleGeometry g,
    VerticalLeg d,
    VerticalScaleMark m,
  ) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: m.passed
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurfaceVariant,
    );
    // The name gives way on a narrow screen; the figure never does.
    return PositionedDirectional(
      start: 0,
      end: g.columnInset,
      top: g.yFor(d, m.labelOffsetPx) - 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              verticalLandmarkName(context.l10n, m.landmark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
          const SizedBox(width: 4),
          // Only at a very large text size can the figure alone outgrow the
          // column; then it scales down rather than overflow.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.max(0, g.width - g.columnInset - 4),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                units.formatDepthWhole(m.landmark.meters),
                style: style,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headline(
    BuildContext context,
    UnitFormatter units,
    VerticalScaleGeometry g,
    VerticalLeg d,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final total = widget.timeline.totalMeters;
    final next = _next(d);
    final bar = _layout.barPx;
    const height = 72.0;
    // The ascent headline is anchored by its bottom edge, which sits level
    // with a typical headline's end beside the bar top but never lower than
    // just above the Sea level label; however many lines its text takes, it
    // grows upward and stays clear of sea level. The descent headline is
    // anchored by its top, which is never above sea level.
    final ascentBottom = math.min(g.seaY - bar + height, g.seaY - 20);
    final descentTop = (g.seaY + bar - height).clamp(
      g.seaY + 6,
      kVerticalScaleHeight - height,
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return PositionedDirectional(
      start: g.columnInset,
      end: 0,
      top: d == VerticalLeg.descent ? descentTop : null,
      bottom: d == VerticalLeg.ascent
          ? kVerticalScaleHeight - ascentBottom
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            units.formatDepthWhole(total),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            d == VerticalLeg.ascent
                ? l10n.insights_profile_verticalDistance_totalAscent
                : l10n.insights_profile_verticalDistance_totalDescent,
            style: muted,
          ),
          // The name gives way on a narrow screen; the distance has a line
          // of its own and never does.
          Text(
            l10n.insights_profile_verticalDistance_next(
              verticalLandmarkName(l10n, next),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
          Text(
            l10n.insights_profile_verticalDistance_toGo(
              units.formatDepthWhole(next.meters - total, roundUp: true),
            ),
            style: muted,
          ),
        ],
      ),
    );
  }

  String _date(UnitFormatter units, DiveVerticalDistance dive) =>
      units.formatDate(wallClockUtcFromMillis(dive.startMillis));

  String _stripText(
    AppLocalizations l10n,
    UnitFormatter units,
    VerticalProbe? probe,
    DiveVerticalDistance? crossing,
  ) {
    if (probe == null) {
      return l10n.insights_profile_verticalDistance_stripIdle;
    }
    final landmark = probe.landmark;
    if (probe.ahead && landmark != null) {
      return l10n.insights_profile_verticalDistance_stripAhead(
        verticalLandmarkName(l10n, landmark),
        units.formatDepthWhole(
          landmark.meters - widget.timeline.totalMeters,
          roundUp: true,
        ),
      );
    }
    final date = crossing == null ? '--' : _date(units, crossing);
    if (landmark != null) {
      return l10n.insights_profile_verticalDistance_stripPassed(
        verticalLandmarkName(l10n, landmark),
        date,
      );
    }
    final level = units.formatDepthWhole(probe.meters);
    return probe.direction == VerticalLeg.ascent
        ? l10n.insights_profile_verticalDistance_stripAscent(level, date)
        : l10n.insights_profile_verticalDistance_stripDescent(level, date);
  }
}
