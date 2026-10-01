import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';

/// At or below this many bar a slot is empty: the planner's default reserve,
/// and on a rental trip the line below which nobody dives the bottle again.
/// A constant, not a setting.
const double kTripCylinderEmptyBar = 50;

/// A fill or adjustment at or above this share of the working pressure is a
/// full bottle: a gauge reading of 190 on a 207 bar cylinder is not a
/// partial, and a short fill below it is not full.
const double kTripCylinderFullFraction = 0.9;

/// Order within the minute a dive starts in: the fills before the dive they
/// were for, the corrections after the dive they correct, seconds breaking
/// ties within each. A fill saved with the default "now" carries seconds and
/// a dive typed into the editor has none, so the minute, not the
/// millisecond, is the dive's instant. Any other minute runs in time order,
/// a fill before a correction on one instant.
const int _rankFill = 0;
const int _rankDive = 1;
const int _rankAdjustment = 2;

class _Item {
  final int at;
  final int rank;
  final TripCylinderEvent? event;
  final TripCylinderTankUse? use;

  /// The minute [at] falls in, the fold's first sort key.
  final int minute;

  _Item({required this.at, required this.rank, this.event, this.use})
    : minute = _minuteOf(at);

  /// Breaks a tie on instant and rank, so every replica folds the same rows
  /// in the same order whatever order the query returned them in.
  String get tieKey => event?.id ?? use!.tankId;
}

/// Pure. Walks the slot's fills, adjustments and linked dive tanks in time
/// order (in a dive's own minute: its fills, the dive, then corrections)
/// and reports where that leaves it. Nothing is stored; a corrected fill time or a late import
/// re-sorts on the next read.
///
/// Rules, applied in order down the timeline:
/// - A fill sets the pressure (its own, else the working pressure), the mix
///   (analyzed over ordered, else unchanged) and the bottle label when it
///   carries one.
/// - An adjustment sets the pressure when it carries one, and the mix when
///   it carries one.
/// - A dive tank sets the pressure to its end pressure; unknown makes the
///   pressure unknown but the slot used. It never changes the slot's mix.
///
/// Status comes from the last item: a fill is full; an adjustment at or
/// above [kTripCylinderFullFraction] of the working pressure is full;
/// otherwise at or below [kTripCylinderEmptyBar] is empty, an unknown
/// pressure is partial, and anything else is partial. No items is unknown.
TripCylinderState foldCylinderState({
  required TripCylinder cylinder,
  required List<TripCylinderEvent> events,
  required List<TripCylinderTankUse> uses,
}) {
  final diveMinutes = {
    for (final u in uses) _minuteOf(u.entryTime.millisecondsSinceEpoch),
  };
  final items =
      <_Item>[
        for (final e in events)
          _Item(
            at: e.occurredAt.millisecondsSinceEpoch,
            rank: e.kind == TripCylinderEventKind.fill
                ? _rankFill
                : _rankAdjustment,
            event: e,
          ),
        for (final u in uses)
          _Item(
            at: u.entryTime.millisecondsSinceEpoch,
            rank: _rankDive,
            use: u,
          ),
      ]..sort((a, b) {
        final byMinute = a.minute.compareTo(b.minute);
        if (byMinute != 0) return byMinute;
        final byTime = a.at.compareTo(b.at);
        final byRank = a.rank.compareTo(b.rank);
        // One scheme per minute, so the order stays total.
        final (first, second) = diveMinutes.contains(a.minute)
            ? (byRank, byTime)
            : (byTime, byRank);
        if (first != 0) return first;
        return second != 0 ? second : a.tieKey.compareTo(b.tieKey);
      });

  double? pressure;
  GasMix? mix;
  String? bottleLabel;
  TripCylinderEvent? lastFill;
  _Item? last;

  for (final item in items) {
    final event = item.event;
    if (event != null) {
      switch (event.kind) {
        case TripCylinderEventKind.fill:
          pressure = event.pressure ?? cylinder.workingPressure;
          mix = event.effectiveMix ?? mix;
          final label = event.bottleLabel;
          if (label != null && label.isNotEmpty) bottleLabel = label;
          lastFill = event;
        case TripCylinderEventKind.adjustment:
          if (event.pressure != null) pressure = event.pressure;
          final adjustedMix = event.effectiveMix;
          if (adjustedMix != null) mix = adjustedMix;
      }
    } else {
      pressure = item.use!.endPressure;
    }
    last = item;
  }

  return TripCylinderState(
    cylinder: cylinder,
    pressure: pressure,
    mix: mix,
    bottleLabel: bottleLabel ?? cylinder.label,
    status: _statusOf(cylinder, last, pressure),
    lastFill: lastFill,
    lastEventAt: last == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(last.at, isUtc: true),
    linkedDiveCount: uses.map((u) => u.diveId).toSet().length,
    lastEvent: last?.event,
    lastUse: last?.use,
  );
}

TripCylinderStatus _statusOf(
  TripCylinder cylinder,
  _Item? last,
  double? pressure,
) {
  if (last == null) return TripCylinderStatus.unknown;
  final event = last.event;
  final isFill = event != null && event.kind == TripCylinderEventKind.fill;
  // A fill logged without a pressure is taken at its word.
  if (pressure == null) {
    return isFill ? TripCylinderStatus.full : TripCylinderStatus.partial;
  }
  // Fills and readings share one set of thresholds, so a short fill reads
  // partial (or empty) rather than full. A dive's end pressure never makes
  // a slot full.
  final working = cylinder.workingPressure;
  if (event != null &&
      working != null &&
      pressure >= kTripCylinderFullFraction * working) {
    return TripCylinderStatus.full;
  }
  if (pressure <= kTripCylinderEmptyBar) return TripCylinderStatus.empty;
  // With no working pressure to measure against, a fill stays full.
  if (isFill && working == null) return TripCylinderStatus.full;
  return TripCylinderStatus.partial;
}

/// Pure. The slot to preselect for a tank being added to a dive on this
/// trip: a full slot not in [excludedCylinderIds] (the slots sibling tanks
/// on the same dive already took). When [tankMix] is not plain air, slots
/// whose mix lands within one point of O2 and He are preferred; with none
/// matching, any full slot will do. Oldest fill first; a slot full by gauge
/// reading, with no fill, sorts last; ties break on board order. Null when
/// nothing is full.
TripCylinder? suggestTripCylinder({
  required List<TripCylinderState> states,
  required GasMix tankMix,
  Set<String> excludedCylinderIds = const {},
}) {
  final full = states
      .where(
        (s) =>
            s.status == TripCylinderStatus.full &&
            !excludedCylinderIds.contains(s.cylinder.id),
      )
      .toList();
  if (full.isEmpty) return null;

  final isAir = (tankMix.o2 - 21).abs() < 0.5 && tankMix.he.abs() < 0.5;
  final matching = isAir
      ? full
      : full.where((s) {
          final mix = s.mix;
          return mix != null &&
              (mix.o2 - tankMix.o2).abs() <= 1.0 &&
              (mix.he - tankMix.he).abs() <= 1.0;
        }).toList();
  final pool = matching.isEmpty ? full : matching;

  int filledAt(TripCylinderState s) =>
      s.lastFill?.occurredAt.millisecondsSinceEpoch ?? _neverFilled;
  pool.sort((a, b) {
    final byFill = filledAt(a).compareTo(filledAt(b));
    return byFill != 0
        ? byFill
        : a.cylinder.sortOrder.compareTo(b.cylinder.sortOrder);
  });
  return pool.first.cylinder;
}

/// Sorts a slot with no fill after every filled one.
const int _neverFilled = 1 << 62;

/// Pure. Every slot as it stood at [atMillis]: its fills and adjustments
/// up to that instant (see [tripCylinderEventsUpTo]), and the dives before
/// it, leaving out [excludeDiveId], the dive being edited, whose own use
/// must not count.
/// For a dive logged now this is the board's current state (decided
/// 2026-09-29: a past dive picks and fills from the slots as they were).
List<TripCylinderState> foldCylinderStatesAt({
  required List<TripCylinder> cylinders,
  required Map<String, List<TripCylinderEvent>> eventsBySlot,
  required Map<String, List<TripCylinderTankUse>> usesBySlot,
  required int atMillis,
  String? excludeDiveId,
}) => [
  for (final c in cylinders)
    foldCylinderState(
      cylinder: c,
      events: tripCylinderEventsUpTo(
        eventsBySlot[c.id] ?? const <TripCylinderEvent>[],
        atMillis,
      ),
      uses: [
        for (final u in usesBySlot[c.id] ?? const <TripCylinderTankUse>[])
          if (u.entryTime.millisecondsSinceEpoch < atMillis &&
              u.diveId != excludeDiveId)
            u,
      ],
    ),
];

/// Pure. The [events] in the slot by [atMillis], a dive's start. A fill
/// counts to the minute: one in the dive's own minute was for that dive,
/// whatever its seconds. A correction counts only up to the instant itself,
/// since in the dive's minute the fold puts corrections after the dive.
/// Every reader of a slot at a dive's start (the editor's picker, the dive
/// detail's bottle line, the gas record) takes its events here.
List<TripCylinderEvent> tripCylinderEventsUpTo(
  List<TripCylinderEvent> events,
  int atMillis,
) {
  final minute = _minuteOf(atMillis);
  return [
    for (final e in events)
      if (e.kind == TripCylinderEventKind.fill
          ? _minuteOf(e.occurredAt.millisecondsSinceEpoch) <= minute
          : e.occurredAt.millisecondsSinceEpoch <= atMillis)
        e,
  ];
}

/// The start of the minute [millis] falls in; floors before 1970 too.
int _minuteOf(int millis) => millis - millis % Duration.millisecondsPerMinute;

/// The fill station the trip used last: the newest of the slots' latest
/// fills that names a dive center. The fill sheet's default (the Bonaire
/// ritual is the same drive-through every morning) and the fill forecast's
/// station for the deadline.
String? lastTripFillCenter(List<TripCylinderState> slots) {
  TripCylinderEvent? latest;
  for (final s in slots) {
    final fill = s.lastFill;
    if (fill == null || fill.diveCenterId == null) continue;
    if (latest == null || fill.occurredAt.isAfter(latest.occurredAt)) {
      latest = fill;
    }
  }
  return latest?.diveCenterId;
}
