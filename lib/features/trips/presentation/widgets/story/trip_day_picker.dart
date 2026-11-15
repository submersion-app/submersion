import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_picker_model.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_picker_painter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The trip story's day picker: a leading Trip tile for the whole trip, then
/// one tile per day that draws the day's dives hanging from the surface.
///
/// The strip is a picture of the trip: every dive is as deep as it went and
/// as wide as it was long, on scales the whole trip shares, so the deep day
/// and the easy days show at a glance. Tapping a tile picks what the page
/// under the strip shows. Days are never changed by swiping: the trip page's
/// tab view already owns horizontal swipes.
///
/// When the days do not fit they scroll sideways, the Trip tile staying
/// fixed at the start edge and the selected day kept in view.
///
/// For a keyboard the strip is one stop, on the selected tile; the arrow
/// keys move the selection and the focus together, as they do in a tab bar.
class TripDayPicker extends StatefulWidget {
  const TripDayPicker({
    super.key,
    required this.days,
    required this.model,
    required this.selectedDate,
    required this.onSelect,
    this.chartHeight = 60,
  });

  /// The story's days, in order.
  final List<TripStoryDay> days;

  /// What each day draws; one entry per day of [days].
  final TripPickerModel model;

  /// The selected day's date; null selects the Trip tile.
  final DateTime? selectedDate;

  /// Called with a day's date, or null for the Trip tile.
  final ValueChanged<DateTime?> onSelect;

  /// The height of each tile's drawing, under its label.
  final double chartHeight;

  static const double tripTileWidth = 40;
  static const double minDayTileWidth = 38;
  static const tripTileKey = Key('trip-picker-tile-trip');
  static Key dayTileKey(int dayNumber) => Key('trip-picker-tile-$dayNumber');

  /// The fades that say the strip continues past an edge.
  static const moreBeforeKey = Key('trip-picker-more-before');
  static const moreAfterKey = Key('trip-picker-more-after');

  @override
  State<TripDayPicker> createState() => _TripDayPickerState();
}

class _TripDayPickerState extends State<TripDayPicker> {
  final _scroll = ScrollController();

  /// One focus node per tile. Only the selected tile's is a tab stop.
  ///
  /// A day's node is held by its date, not its place in the strip, and its
  /// tile is keyed by date too: days added or removed in front of it (a dive
  /// logged before the trip's start) move the focus with its day.
  final _tripFocus = FocusNode(debugLabel: 'trip picker: trip');
  final _dayFocus = <DateTime, FocusNode>{};

  /// The day tiles' width and the space they scroll in, from the last
  /// layout, for bringing the selected day into view.
  double _tileWidth = TripDayPicker.minDayTileWidth;
  double _viewport = 0;

  /// Whether the strip continues past its start and its end edge.
  final _more = ValueNotifier<({bool before, bool after})>((
    before: false,
    after: false,
  ));

  int get _selectedIndex => _indexIn(widget);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateMore);
    _syncFocusNodes();
    _showSelectedAfterFrame(animate: false);
  }

  /// One node per day, and the tab stop on the selected tile.
  void _syncFocusNodes() {
    final dates = {for (final day in widget.days) day.date};
    final dropped = [
      for (final MapEntry(key: date, value: node) in _dayFocus.entries)
        if (!dates.contains(date)) node,
    ];
    if (dropped.isNotEmpty) {
      _dayFocus.removeWhere((date, _) => !dates.contains(date));
      // Asked now: once this build unmounts their tiles, they have let go.
      final hadFocus = dropped.any((node) => node.hasFocus);
      // Their tiles are still mounted until this build is over.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final node in dropped) {
          node.dispose();
        }
        // The day that had the focus is gone: hand it to the tab stop, so
        // the keyboard stays in the strip.
        if (hadFocus && mounted) _tabStop.requestFocus();
      });
    }
    for (final date in dates) {
      _dayFocus.putIfAbsent(
        date,
        () => FocusNode(debugLabel: 'trip picker: $date'),
      );
    }
    final selected = widget.selectedDate;
    _tripFocus.skipTraversal = _selectedIndex >= 0;
    for (final MapEntry(key: date, value: node) in _dayFocus.entries) {
      node.skipTraversal = date != selected;
    }
  }

  /// The selected tile's node: the strip's one tab stop.
  FocusNode get _tabStop {
    final index = _selectedIndex;
    return index < 0 ? _tripFocus : _dayFocus[widget.days[index].date]!;
  }

  void _updateMore() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    _more.value = (
      before: position.extentBefore > 0.5,
      after: position.extentAfter > 0.5,
    );
  }

  @override
  void didUpdateWidget(TripDayPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocusNodes();
    if (oldWidget.selectedDate != widget.selectedDate) {
      _showSelectedAfterFrame(animate: true);
    } else if (_indexIn(oldWidget) != _selectedIndex) {
      // The same day, at a new place: days were added or removed in front of
      // it (a dive logged before the trip's start). Its tile moved with them,
      // possibly past the edge; bring it back without a slide.
      _showSelectedAfterFrame(animate: false);
    }
  }

  static int _indexIn(TripDayPicker picker) => picker.selectedDate == null
      ? -1
      : picker.days.indexWhere((d) => d.date == picker.selectedDate);

  @override
  void dispose() {
    _scroll.dispose();
    _more.dispose();
    _tripFocus.dispose();
    for (final node in _dayFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _showSelectedAfterFrame({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final index = _selectedIndex;
      if (index < 0) return;
      final position = _scroll.position;
      final start = index * _tileWidth;
      final end = start + _tileWidth;
      double? target;
      if (start < position.pixels) {
        target = start;
      } else if (end > position.pixels + _viewport) {
        target = end - _viewport;
      }
      if (target == null) return;
      target = target.clamp(0.0, position.maxScrollExtent);
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  /// Moves the selection one tile along the order Trip, day 1, day 2...,
  /// and the focus with it: the keys are only heard while a tile has focus,
  /// and left behind it would sit on a tile that is no longer the one shown.
  void _step(int delta) {
    final next = _selectedIndex + delta;
    if (next < -1 || next >= widget.days.length) return;
    final date = next < 0 ? null : widget.days[next].date;
    widget.onSelect(date);
    (date == null ? _tripFocus : _dayFocus[date]!).requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final forward = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _step(forward);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _step(-forward);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Larger accessibility text needs wider tiles, or a weekday would be
    // clipped by its own tile.
    final grow = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final tripWidth = TripDayPicker.tripTileWidth * grow;
    final minDayWidth = TripDayPicker.minDayTileWidth * grow;
    final selectedIndex = _selectedIndex;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        // The Trip tile and the day tiles are the same height: each is a
        // label of fixed height (see _TileLabel) over the same chart height.
        // So the row needs no intrinsic pass, which a LayoutBuilder could
        // not take part in.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The rule between the Trip tile and the days is this box's
            // end border, so it is exactly as tall as the tile.
            Container(
              width: tripWidth + 1,
              decoration: BoxDecoration(
                border: BorderDirectional(
                  end: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: _TripTile(
                selected: selectedIndex < 0,
                focusNode: _tripFocus,
                chartHeight: widget.chartHeight,
                onTap: () => widget.onSelect(null),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = widget.days.length;
                  final tileWidth = math.max(
                    minDayWidth,
                    constraints.maxWidth / math.max(1, count),
                  );
                  _tileWidth = tileWidth;
                  _viewport = constraints.maxWidth;
                  // The extents are known only after this layout.
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _updateMore(),
                  );
                  return Stack(
                    children: [
                      // Drag by mouse as well as touch: on desktop a long
                      // trip's days run past the pane, and a horizontal
                      // scroll view takes no mouse drag by default.
                      ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: PointerDeviceKind.values.toSet(),
                        ),
                        child: SingleChildScrollView(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < count; i++)
                                SizedBox(
                                  // By date: a tile, and the focus it may
                                  // hold, moves with its day.
                                  key: ValueKey(widget.days[i].date),
                                  width: tileWidth,
                                  child: _DayTile(
                                    day: widget.days[i],
                                    shapes: widget.model.days[i],
                                    model: widget.model,
                                    selected: i == selectedIndex,
                                    focusNode: _dayFocus[widget.days[i].date]!,
                                    chartHeight: widget.chartHeight,
                                    onTap: () =>
                                        widget.onSelect(widget.days[i].date),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // A short fade over an edge the strip continues past.
                      ValueListenableBuilder(
                        valueListenable: _more,
                        builder: (context, more, _) => Stack(
                          children: [
                            if (more.before)
                              const _EdgeFade(
                                key: TripDayPicker.moreBeforeKey,
                                atStart: true,
                              ),
                            if (more.after)
                              const _EdgeFade(
                                key: TripDayPicker.moreAfterKey,
                                atStart: false,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tile's shell: one semantics node, one tap target, tinted when selected.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // One node carrying the label, the button role and the selected state.
    // The selected state sits on the tappable node itself: placed on a
    // wrapper above it, it would not merge into what a screen reader taps.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(focusNode: focusNode, onTap: onTap, child: child),
      ),
    );
  }
}

/// The two-line label over a tile's drawing. Scales down before it would be
/// clipped by a tile that could grow no further.
class _TileLabel extends StatelessWidget {
  const _TileLabel({
    required this.top,
    required this.bottom,
    required this.selected,
    this.emphasised = false,
  });

  final String top;
  final String bottom;
  final bool selected;

  /// Today's tile: primary and bold, the emphasis the page gives today.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strong = selected
        ? scheme.onPrimaryContainer
        : (emphasised ? scheme.primary : scheme.onSurface);
    final quiet = selected
        ? scheme.onPrimaryContainer
        : (emphasised ? scheme.primary : scheme.onSurfaceVariant);
    final topStyle = theme.textTheme.labelSmall?.copyWith(
      color: quiet,
      fontWeight: emphasised ? FontWeight.bold : null,
    );
    final bottomStyle = theme.textTheme.titleSmall?.copyWith(
      color: strong,
      fontWeight: FontWeight.bold,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 3),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sets the label's height. A label too wide for its tile is
            // scaled down below, and scaling shrinks height with width: left
            // to size itself, such a tile would be shorter than its
            // neighbours and its surface line would sit higher than theirs.
            // One space per line is never too wide, so it is never scaled.
            ExcludeSemantics(
              child: Opacity(
                opacity: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(' ', maxLines: 1, style: topStyle),
                    Text(' ', maxLines: 1, style: bottomStyle),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(top, maxLines: 1, style: topStyle),
                    Text(bottom, maxLines: 1, style: bottomStyle),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short fade over one edge of the strip, saying it continues that way.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({super.key, required this.atStart});

  final bool atStart;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return PositionedDirectional(
      start: atStart ? 0 : null,
      end: atStart ? null : 0,
      top: 0,
      bottom: 0,
      width: 20,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: atStart
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.centerEnd,
              end: atStart
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              colors: [surface, surface.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({
    required this.selected,
    required this.focusNode,
    required this.chartHeight,
    required this.onTap,
  });

  final bool selected;
  final FocusNode focusNode;
  final double chartHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return _Tile(
      key: TripDayPicker.tripTileKey,
      label: l10n.trips_story_tripTile_semantics,
      selected: selected,
      focusNode: focusNode,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TileLabel(
            top: l10n.trips_story_tripTile,
            bottom: l10n.trips_story_tripTileAll,
            selected: selected,
          ),
          SizedBox(
            height: chartHeight,
            child: Center(
              child: Icon(
                Icons.view_agenda_outlined,
                size: 18,
                color: selected ? scheme.onPrimaryContainer : scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends ConsumerWidget {
  const _DayTile({
    required this.day,
    required this.shapes,
    required this.model,
    required this.selected,
    required this.focusNode,
    required this.chartHeight,
    required this.onTap,
  });

  final TripStoryDay day;
  final TripPickerDay shapes;
  final TripPickerModel model;
  final bool selected;
  final FocusNode focusNode;
  final double chartHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final units = ref.watch(unitFormatterProvider);
    final isToday = day.kind == TripStoryDayKind.today;
    final maxDepth = day.maxDepth;
    final label = [
      l10n.trips_story_dayTile_semantics(
        units.formatWeekdayMonthDay(day.date),
        day.dayNumber,
      ),
      if (day.diveCount > 0)
        l10n.diveLog_listPage_tripGroupDiveCount(day.diveCount),
      if (maxDepth != null)
        l10n.trips_story_dayTile_deepest(units.formatDepth(maxDepth)),
      if (isToday) l10n.trips_story_today,
    ].join(', ');

    return _Tile(
      key: TripDayPicker.dayTileKey(day.dayNumber),
      label: label,
      selected: selected,
      focusNode: focusNode,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TileLabel(
            // The weekday follows Intl.defaultLocale, which the app sets
            // from its own locale. The day of month is a bare number: it has
            // no order for a date preference to change.
            top: DateFormat.E().format(day.date),
            bottom: '${day.date.day}',
            selected: selected,
            emphasised: isToday,
          ),
          CustomPaint(
            size: Size.fromHeight(chartHeight),
            painter: TripDayPickerPainter(
              day: shapes,
              maxDepth: model.maxDepth,
              widestDaySeconds: model.widestDaySeconds,
              surfaceColor: scheme.primary,
              // The outline's colour; the fill is this at fillOpacity. An
              // unselected day is a muted tone of the same hue.
              shapeColor: selected
                  ? scheme.onPrimaryContainer
                  : scheme.primary.withValues(alpha: 0.6),
              fillOpacity: selected ? 0.55 : 0.75,
            ),
          ),
        ],
      ),
    );
  }
}
