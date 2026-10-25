import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_context_painter.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_density_painter.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_panel_edge.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_tick_painter.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_thumb_style.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

/// The frosted panel behind an active scrubber, with [markers] centred
/// at their track positions and, while dragging, [currentLabel] (with
/// [currentDetail] under it) beside a marker line on a band level with the
/// thumb at [thumbTop]. It fades in and out with [reveal].
class ListScrubberPanel extends StatefulWidget {
  const ListScrubberPanel({
    super.key,
    required this.markers,
    required this.slotCount,
    required this.trackExtent,
    required this.thumbHeight,
    required this.thumbTop,
    this.currentLabel,
    this.currentDetail,
    this.currentHeight,
    this.currentWidth = width,
    this.labelColumn = width,
    this.reveal = 1,
    this.ticks = const [],
    this.tickColor,
    this.thumbInset = 0,
    this.segments = const [],
    this.contextTicks = const [],
    this.density = const [],
  });

  /// The widest the label column gets; longer marker labels end in "...".
  static const width = 64.0;

  /// The panel's width: its [labelColumn], plus [densityColumn] at its start
  /// edge for density bars when there are any.
  static double widthFor({
    required double labelColumn,
    required bool density,
  }) => density ? labelColumn + densityColumn : labelColumn;

  /// The density bars' column, with a gap before the markers.
  static const densityColumn = ListScrubberDensityPainter.columnEnd + 2;
  static const maxBandWidth = 230.0;

  /// How much of the panel's fill covers the blurred list behind it.
  static const fillAlpha = 0.6;

  /// The blur of the list behind the panel, fully revealed.
  static const blurSigma = 8.0;

  /// Marks the padded box around each marker label.
  static const labelBackingKey = ValueKey('list-scrubber-label-backing');
  static const currentBandKey = ValueKey('listScrubber.currentBand');
  static const currentValueKey = ValueKey('listScrubber.currentValue');
  static const currentDetailKey = ValueKey('listScrubber.currentDetail');
  static const currentMarkerKey = ValueKey('listScrubber.currentMarker');
  static const _ticksKey = ValueKey('listScrubber.ticks');
  static const _contextKey = ValueKey('listScrubber.context');
  static const _markerSpacing = 28.0;
  static const _labelHeight = 16.0;
  static const _coverHeight = 40.0;
  static const _startPadding = 4.0;
  static const _thumbReserve = 14.0;
  static const _labelGap = 4.0;
  static const _minLine = 12.0;
  static const _labelPadding = 6.0;
  static const _markerPadding = 2.0;
  static const _bandPadding = 4.0;

  static TextStyle? markerStyle(ThemeData theme) => theme.textTheme.labelSmall
      ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

  static TextStyle? currentStyle(ThemeData theme) =>
      markerStyle(theme)?.copyWith(fontWeight: FontWeight.w700);

  /// The size [value] in [currentStyle] and, under it, [detail] in
  /// [markerStyle] on up to two lines take within [maxWidth].
  static Size textSize(
    BuildContext context, {
    required String value,
    String? detail,
    required double maxWidth,
  }) {
    final theme = Theme.of(context);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final valuePainter = TextPainter(
      text: TextSpan(text: value, style: currentStyle(theme)),
      maxLines: 1,
      ellipsis: _ellipsis,
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    var width = valuePainter.width;
    var height = valuePainter.height;
    valuePainter.dispose();
    if (detail != null) {
      final detailPainter = TextPainter(
        text: TextSpan(text: detail, style: markerStyle(theme)),
        maxLines: 2,
        ellipsis: _ellipsis,
        textDirection: direction,
        textScaler: scaler,
        textWidthBasis: TextWidthBasis.longestLine,
      )..layout(maxWidth: maxWidth);
      width = math.max(width, detailPainter.width);
      height += detailPainter.height;
      detailPainter.dispose();
    }
    return Size(width, height);
  }

  /// The current band that fits [value] and [detail] in a host [hostWidth]
  /// wide, at least as wide as the panel's [panelWidth].
  static Size bandSize(
    BuildContext context, {
    required String value,
    String? detail,
    required double hostWidth,
    required double panelWidth,
  }) {
    final cap = math.max(0.0, math.min(maxBandWidth, hostWidth - 16));
    final text = textSize(
      context,
      value: value,
      detail: detail,
      maxWidth: math.max(0.0, cap - _labelPadding * 2 - _chrome),
    );
    final needed = text.width + _labelPadding * 2 + _chrome;
    return Size(
      math.min(math.max(needed, panelWidth), cap),
      text.height + _bandPadding * 2,
    );
  }

  /// The label column that fits the widest of [markers] beside a thumb
  /// [thumbInset] wide, at most [width].
  static double labelColumnFor(
    BuildContext context,
    List<ScrubberMarker> markers, {
    required double thumbInset,
  }) {
    final style = markerStyle(Theme.of(context));
    final painter = TextPainter(
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    final seen = <String>{};
    var widest = 0.0;
    for (final marker in markers) {
      if (!seen.add(marker.label)) continue;
      painter
        ..text = TextSpan(text: marker.label, style: style)
        ..layout();
      widest = math.max(widest, painter.width);
      if (widest >= width) break;
    }
    painter.dispose();
    // Whole pixels, so the widest label is never ellipsized by rounding.
    return math.min(
      width,
      widest.ceilToDouble() + _markerPadding * 2 + thumbInset,
    );
  }

  static const _ellipsis = '\u2026';
  static const _chrome = _startPadding + _labelGap + _minLine + _thumbReserve;

  final List<ScrubberMarker> markers;
  final int slotCount;
  final double trackExtent;
  final double thumbHeight;
  final double thumbTop;
  final String? currentLabel;

  /// A second line under [currentLabel], such as the trip a dive is on.
  final String? currentDetail;

  /// The current band's height, when the caller has laid it out already
  /// with [bandSize]; measured here when null.
  final double? currentHeight;

  /// The width of the current band; beyond the panel's width it sticks out
  /// past the panel's start edge.
  final double currentWidth;

  /// The width of the column holding the markers and the thumb.
  final double labelColumn;

  /// How far the panel has faded in, from 0 (hidden) to 1.
  final double reveal;

  /// Slots marked with a tick beside the thumb track.
  final List<int> ticks;

  /// The ticks' colour; `primary` when null.
  final Color? tickColor;

  /// The thumb track's width from the panel's end edge.
  final double thumbInset;

  /// Stripes in the context column at the panel's start edge.
  final List<ScrubberSegment> segments;

  /// Ticks in the context column at the panel's start edge.
  final List<ScrubberTick> contextTicks;

  /// Item counts drawn as bars in a column beside the context column.
  final List<ScrubberDensityBin> density;

  @override
  State<ListScrubberPanel> createState() => _ListScrubberPanelState();
}

typedef _PlacedMarker = ({ScrubberMarker marker, double top});

class _ListScrubberPanelState extends State<ListScrubberPanel> {
  List<ScrubberMarker>? _tracksMarkers;
  int? _tracksSlotCount;
  double? _tracksExtent;
  List<double> _tops = const [];

  /// For each marker, the kept marker that thinned it away, or null if kept.
  List<int?> _suppressor = const [];

  List<int> _covered = const [];
  List<_PlacedMarker>? _visible;

  void _refreshTops() {
    final w = widget;
    if (identical(_tracksMarkers, w.markers) &&
        _tracksSlotCount == w.slotCount &&
        _tracksExtent == w.trackExtent) {
      return;
    }
    _tracksMarkers = w.markers;
    _tracksSlotCount = w.slotCount;
    _tracksExtent = w.trackExtent;
    _tops = [
      for (final marker in w.markers)
        trackForSlot(
          slot: marker.slot,
          trackExtent: w.trackExtent,
          slotCount: w.slotCount,
        ),
    ];
    final kept = thinMarkers(
      w.markers,
      slotCount: w.slotCount,
      trackExtent: w.trackExtent,
      minSpacing: ListScrubberPanel._markerSpacing,
    );
    final suppressor = List<int?>.filled(_tops.length, null);
    var k = 0;
    int? lastKept;
    for (var i = 0; i < _tops.length; i++) {
      if (k < kept.length && identical(w.markers[i], kept[k])) {
        k++;
        lastKept = i;
      } else {
        suppressor[i] = lastKept;
      }
    }
    _suppressor = suppressor;
    _visible = null;
  }

  /// The thinned markers minus those level with the thumb, plus any that
  /// frees which still keep their spacing. Recomputed only when the markers,
  /// the track or the set of markers level with the thumb changes.
  List<_PlacedMarker> _visibleMarkers() {
    _refreshTops();
    const reach =
        (ListScrubberPanel._coverHeight + ListScrubberPanel._labelHeight) / 2;
    const spacing = ListScrubberPanel._markerSpacing;
    final covered = [
      for (var i = 0; i < _tops.length; i++)
        if ((_tops[i] - widget.thumbTop).abs() < reach) i,
    ];
    final cached = _visible;
    if (cached != null && listEquals(covered, _covered)) return cached;
    _covered = covered;
    final hidden = covered.toSet();
    final nextKept = List<double?>.filled(_tops.length, null);
    double? next;
    for (var i = _tops.length - 1; i >= 0; i--) {
      nextKept[i] = next;
      if (_suppressor[i] == null && !hidden.contains(i)) next = _tops[i];
    }
    final shown = <_PlacedMarker>[];
    double? last;
    for (var i = 0; i < _tops.length; i++) {
      if (hidden.contains(i)) continue;
      final top = _tops[i];
      final by = _suppressor[i];
      if (by != null) {
        if (!hidden.contains(by)) continue;
        if (last != null && top - last < spacing) continue;
        final after = nextKept[i];
        if (after != null && after - top < spacing) continue;
      }
      shown.add((marker: widget.markers[i], top: top));
      last = top;
    }
    return _visible = shown;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = ListScrubberPanel.markerStyle(theme);
    final fill = colors.surfaceContainerHigh.withValues(
      alpha: ListScrubberPanel.fillAlpha,
    );
    final centre = widget.thumbHeight / 2;
    final current = widget.currentLabel;
    final bandHeight = current == null
        ? 0.0
        : widget.currentHeight ??
              ListScrubberPanel.textSize(
                    context,
                    value: current,
                    detail: widget.currentDetail,
                    maxWidth: math.max(
                      0.0,
                      _labelMax - ListScrubberPanel._labelPadding * 2,
                    ),
                  ).height +
                  ListScrubberPanel._bandPadding * 2;
    final bandTop = widget.thumbTop + centre - bandHeight / 2;
    final band = current == null
        ? null
        : (top: bandTop, bottom: bandTop + bandHeight);
    final panelWidth = ListScrubberPanel.widthFor(
      labelColumn: widget.labelColumn,
      density: widget.density.isNotEmpty,
    );
    final overhang = widget.currentWidth - panelWidth;
    final tab = band != null && overhang > 0
        ? (top: band.top, bottom: band.bottom, overhang: overhang)
        : null;
    final sigma = ListScrubberPanel.blurSigma * widget.reveal;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: _frost(sigma)),
        if (tab != null)
          PositionedDirectional(
            start: -tab.overhang,
            width: tab.overhang,
            top: tab.top,
            height: tab.bottom - tab.top,
            child: _frost(sigma),
          ),
        Positioned.fill(
          child: Opacity(
            opacity: widget.reveal,
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill),
              child: CustomPaint(
                painter: ListScrubberPanelEdge(
                  fill: fill,
                  edge: colors.outlineVariant,
                  textDirection: Directionality.of(context),
                  tab: tab,
                ),
                child: SizedBox.expand(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final m in _visibleMarkers())
                        PositionedDirectional(
                          end: widget.thumbInset,
                          width: math.max(
                            0.0,
                            widget.labelColumn - widget.thumbInset,
                          ),
                          top: m.top + centre,
                          child: FractionalTranslation(
                            translation: const Offset(0, -0.5),
                            child: Center(
                              child: Padding(
                                key: ListScrubberPanel.labelBackingKey,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ListScrubberPanel._markerPadding,
                                ),
                                child: Text(
                                  m.marker.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.segments.isNotEmpty ||
                          widget.contextTicks.isNotEmpty)
                        Positioned.fill(
                          key: ListScrubberPanel._contextKey,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: ListScrubberContextPainter(
                                segments: widget.segments,
                                ticks: widget.contextTicks,
                                slotCount: widget.slotCount,
                                trackExtent: widget.trackExtent,
                                offset: centre,
                                textDirection: Directionality.of(context),
                                clear: band,
                              ),
                            ),
                          ),
                        ),
                      if (widget.density.isNotEmpty)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: ListScrubberDensityPainter(
                                bins: widget.density,
                                slotCount: widget.slotCount,
                                trackExtent: widget.trackExtent,
                                offset: centre,
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.35,
                                ),
                                textDirection: Directionality.of(context),
                                clear: band,
                              ),
                            ),
                          ),
                        ),
                      if (widget.ticks.isNotEmpty)
                        Positioned.fill(
                          key: ListScrubberPanel._ticksKey,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: ListScrubberTickPainter(
                                ticks: widget.ticks,
                                slotCount: widget.slotCount,
                                trackExtent: widget.trackExtent,
                                offset: centre,
                                endInset: widget.thumbInset,
                                color: widget.tickColor ?? colors.primary,
                                textDirection: Directionality.of(context),
                              ),
                            ),
                          ),
                        ),
                      if (current != null)
                        _currentRow(
                          theme,
                          current,
                          bandTop,
                          bandHeight,
                          panelWidth,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Blurs the list behind the panel, outside the fade so it reads the list
  /// rather than the fade's own empty layer.
  Widget _frost(double sigma) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: const SizedBox.expand(),
    ),
  );

  /// The widest the current value and its detail may be, padding included.
  double get _labelMax => math.max(
    0.0,
    widget.currentWidth -
        ListScrubberPanel._startPadding -
        ListScrubberPanel._thumbReserve -
        ListScrubberPanel._labelGap -
        ListScrubberPanel._minLine,
  );

  Widget _padded({Key? key, required Widget child}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(
      horizontal: ListScrubberPanel._labelPadding,
    ),
    child: child,
  );

  /// The current value, styled like a marker but bold, with its detail under
  /// it in the marker style, and its marker line on a band level with the
  /// thumb. A band wider than the panel sticks out
  /// past its start edge over the tab the edge painter draws.
  Widget _currentRow(
    ThemeData theme,
    String label,
    double top,
    double height,
    double panelWidth,
  ) {
    final colors = theme.colorScheme;
    final fits = widget.currentWidth <= panelWidth;
    final bandWidth = fits
        ? math.max(0.0, widget.currentWidth - 1)
        : widget.currentWidth;
    final labelMax = _labelMax;
    final detail = widget.currentDetail;
    return PositionedDirectional(
      end: 0,
      width: bandWidth,
      top: top,
      height: height,
      child: KeyedSubtree(
        key: ListScrubberPanel.currentBandKey,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start:
                ListScrubberPanel._startPadding -
                (widget.currentWidth - bandWidth),
            end: ListScrubberPanel._thumbReserve,
          ),
          child: Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: labelMax),
                child: _padded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        key: ListScrubberPanel.currentValueKey,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: ListScrubberPanel.currentStyle(theme),
                      ),
                      if (detail != null)
                        Text(
                          detail,
                          key: ListScrubberPanel.currentDetailKey,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textWidthBasis: TextWidthBasis.longestLine,
                          style: ListScrubberPanel.markerStyle(theme),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: ListScrubberPanel._labelGap),
              Expanded(
                child: Container(
                  key: ListScrubberPanel.currentMarkerKey,
                  height: 2,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scrubber thumb: a pill drawn like the app's scrollbar thumb, with
/// thickness, colour and radius taken from [style].
class ListScrubberHandle extends StatelessWidget {
  const ListScrubberHandle({super.key, required this.style});

  /// The thumb's length along the track, which the scrubber's hit box and
  /// track maths use too.
  static const height = 48.0;

  final ListScrubberThumbStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: style.thickness,
      height: height,
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.all(style.radius),
      ),
    );
  }
}
