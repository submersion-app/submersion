import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';

/// At or below this many bar a slot is empty: the planner's default reserve,
/// and on a rental trip the line below which nobody dives the bottle again.
/// A constant, not a setting.
const double kTripCylinderEmptyBar = 50;

/// An adjustment at or above this share of the working pressure is a full
/// bottle: a gauge reading of 190 on a 207 bar cylinder is not a partial.
const double kTripCylinderFullFraction = 0.9;

/// Order on one instant: the fill before the dive it was for, a correction
/// after the dive it corrects.
const int _rankFill = 0;
const int _rankDive = 1;
const int _rankAdjustment = 2;

class _Item {
  final int at;
  final int rank;
  final TripCylinderEvent? event;
  final TripCylinderTankUse? use;

  const _Item({required this.at, required this.rank, this.event, this.use});

  /// Breaks a tie on instant and rank, so every replica folds the same rows
  /// in the same order whatever order the query returned them in.
  String get tieKey => event?.id ?? use!.tankId;
}

/// Pure. Walks the slot's fills, adjustments and linked dive tanks in time
/// order and reports where that leaves it. Nothing is stored; a corrected
/// fill time or a late import re-sorts on the next read.
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
        final byTime = a.at.compareTo(b.at);
        if (byTime != 0) return byTime;
        final byRank = a.rank.compareTo(b.rank);
        return byRank != 0 ? byRank : a.tieKey.compareTo(b.tieKey);
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
  );
}

TripCylinderStatus _statusOf(
  TripCylinder cylinder,
  _Item? last,
  double? pressure,
) {
  if (last == null) return TripCylinderStatus.unknown;
  final event = last.event;
  if (event != null && event.kind == TripCylinderEventKind.fill) {
    return TripCylinderStatus.full;
  }
  final working = cylinder.workingPressure;
  if (event != null &&
      event.kind == TripCylinderEventKind.adjustment &&
      pressure != null &&
      working != null &&
      pressure >= kTripCylinderFullFraction * working) {
    return TripCylinderStatus.full;
  }
  if (pressure == null) return TripCylinderStatus.partial;
  if (pressure <= kTripCylinderEmptyBar) return TripCylinderStatus.empty;
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
