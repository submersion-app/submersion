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

/// The vertical scale and its readout strip (issue #4569).
///
/// Pointing at a bar selects a level: hovering follows the pointer, a click
/// or a tap pins it, and press-and-hold then drag scrubs along the bar. No
/// drag recognizer is attached, so an ordinary swipe always reaches the
/// page's scroll view.
class VerticalDistanceScale extends ConsumerStatefulWidget {
  const VerticalDistanceScale({super.key, required this.timeline});

  final VerticalDistanceTimeline timeline;

  @override
  ConsumerState<VerticalDistanceScale> createState() =>
      _VerticalDistanceScaleState();
}

class _VerticalDistanceScaleState extends ConsumerState<VerticalDistanceScale> {
  VerticalSelection _selection = const VerticalIdle();
  late VerticalScaleLayout _layout = _layoutFor(widget.timeline);

  static VerticalScaleLayout _layoutFor(VerticalDistanceTimeline t) =>
      VerticalScaleLayout.compute(
        totalMeters: t.totalMeters,
        halfHeightPx: kVerticalScaleHalfHeight,
      );

  @override
  void didUpdateWidget(VerticalDistanceScale old) {
    super.didUpdateWidget(old);
    if (old.timeline != widget.timeline) {
      _layout = _layoutFor(widget.timeline);
      _selection = const VerticalIdle();
    }
  }

  void _set(VerticalSelection next) {
    if (!identical(next, _selection)) setState(() => _selection = next);
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);
    final l10n = context.l10n;
    final probe = _selection.probe;
    final crossing = probe == null || probe.ahead
        ? null
        : widget.timeline.crossingAt(probe.meters);

    return Column(
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
        VerticalDistanceStrip(
          key: const Key('verticalStrip'),
          text: _stripText(l10n, units, probe, crossing),
          selected: probe != null,
          pinned: _selection is VerticalPinned,
          onOpen: crossing == null
              ? null
              : () => context.push('/dives/${crossing.diveId}'),
        ),
      ],
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
              probe: _selection.probe,
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

    final nextUp = nextLandmark(VerticalLeg.ascent, total);
    final nextDown = nextLandmark(VerticalLeg.descent, total);
    return SizedBox(
      key: const Key('verticalScale'),
      width: width,
      height: kVerticalScaleHeight,
      child: MouseRegion(
        onHover: (e) =>
            _set(hoverSelection(_selection, g.probeAt(e.localPosition))),
        onExit: (_) => _set(exitSelection(_selection)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) =>
              _set(tapSelection(_selection, g.probeAt(e.localPosition))),
          onLongPressStart: (e) =>
              _set(tapSelection(_selection, g.probeAt(e.localPosition))),
          onLongPressMoveUpdate: (e) {
            final p = g.probeAt(e.localPosition);
            if (p != null) _set(tapSelection(_selection, p));
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  container: true,
                  label: l10n.insights_profile_verticalDistance_semantics(
                    units.formatDepthWhole(total),
                    verticalLandmarkName(l10n, nextUp),
                    units.formatDepthWhole(nextUp.meters - total),
                    verticalLandmarkName(l10n, nextDown),
                    units.formatDepthWhole(nextDown.meters - total),
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
    return PositionedDirectional(
      start: 0,
      end: g.columnInset,
      top: g.yFor(d, m.labelOffsetPx) - 8,
      child: Text(
        context.l10n.insights_profile_verticalDistance_landmarkLabel(
          verticalLandmarkName(context.l10n, m.landmark),
          units.formatDepthWhole(m.landmark.meters),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: theme.textTheme.labelSmall?.copyWith(
          color: m.passed
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
        ),
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
    final next = nextLandmark(d, total);
    final bar = _layout.barPx;
    const height = 72.0;
    final top = d == VerticalLeg.ascent
        ? (g.seaY - bar).clamp(0.0, g.seaY - 90)
        : (g.seaY + bar - height).clamp(
            g.seaY + 6,
            kVerticalScaleHeight - height,
          );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return PositionedDirectional(
      start: g.columnInset,
      end: 0,
      top: top,
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
          Text(
            l10n.insights_profile_verticalDistance_next(
              verticalLandmarkName(l10n, next),
              units.formatDepthWhole(next.meters - total),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
        units.formatDepthWhole(landmark.meters - widget.timeline.totalMeters),
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
