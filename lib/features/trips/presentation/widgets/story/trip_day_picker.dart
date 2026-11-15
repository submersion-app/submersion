import 'dart:math' as math;

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
class TripDayPicker extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<TripDayPicker> createState() => _TripDayPickerState();
}

class _TripDayPickerState extends ConsumerState<TripDayPicker> {
  final _scroll = ScrollController();

  /// The day tiles' width and the space they scroll in, from the last
  /// layout, for bringing the selected day into view.
  double _tileWidth = TripDayPicker.minDayTileWidth;
  double _viewport = 0;

  int get _selectedIndex => widget.selectedDate == null
      ? -1
      : widget.days.indexWhere((d) => d.date == widget.selectedDate);

  @override
  void initState() {
    super.initState();
    _showSelectedAfterFrame(animate: false);
  }

  @override
  void didUpdateWidget(TripDayPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _showSelectedAfterFrame(animate: true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
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

  /// Moves the selection one tile along the order Trip, day 1, day 2...
  void _step(int delta) {
    final next = _selectedIndex + delta;
    if (next < -1 || next >= widget.days.length) return;
    widget.onSelect(next < 0 ? null : widget.days[next].date);
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
        // The Trip tile and the day tiles are the same height by
        // construction (the same label over the same chart height), so the
        // row needs no intrinsic pass, which a LayoutBuilder could not take
        // part in.
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
                  return SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < count; i++)
                          SizedBox(
                            width: tileWidth,
                            child: _DayTile(
                              day: widget.days[i],
                              shapes: widget.model.days[i],
                              model: widget.model,
                              selected: i == selectedIndex,
                              chartHeight: widget.chartHeight,
                              onTap: () => widget.onSelect(widget.days[i].date),
                            ),
                          ),
                      ],
                    ),
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
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
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
        child: InkWell(onTap: onTap, child: child),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 3),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              top,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: quiet,
                fontWeight: emphasised ? FontWeight.bold : null,
              ),
            ),
            Text(
              bottom,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: strong,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({
    required this.selected,
    required this.chartHeight,
    required this.onTap,
  });

  final bool selected;
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
    required this.chartHeight,
    required this.onTap,
  });

  final TripStoryDay day;
  final TripPickerDay shapes;
  final TripPickerModel model;
  final bool selected;
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
