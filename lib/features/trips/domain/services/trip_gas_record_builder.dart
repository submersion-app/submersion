import 'dart:math' as math;

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

/// Pure. The trip's gas record. Each tank's bottle, fill and analysis come
/// from the state fold over the slot's events up to the dive's entry (a
/// fill at the dive's own minute was for that dive), the rule the dive
/// detail line uses, so a bottle swapped mid-week is credited correctly on
/// both sides of the swap. Rows run in dive order, then tank order.
TripGasRecord buildTripGasRecord({
  required List<TripCylinder> cylinders,
  required Map<String, List<TripCylinderEvent>> eventsBySlot,
  required List<TripGasRecordTank> tanks,
  List<TripUnlinkedTank> unlinked = const [],
  required GasModel gasModel,
  required String defaultCurrency,
}) {
  final bySlot = {for (final c in cylinders) c.id: c};
  final ordered = [...tanks]
    ..sort(_inDiveOrder((t) => (t.entryTime, t.diveId, t.tankOrder)));
  final rows = [
    for (final t in ordered)
      if (bySlot[t.tripCylinderId] case final cylinder?)
        _row(t, cylinder, eventsBySlot[cylinder.id] ?? const [], gasModel),
  ];

  final rowsBySlot = <String, List<TripGasRecordRow>>{};
  for (final r in rows) {
    (rowsBySlot[r.cylinder.id] ??= []).add(r);
  }
  final slots = [
    for (final c in cylinders) _slotTotal(c, rowsBySlot[c.id] ?? const []),
  ];

  final fills = [
    for (final list in eventsBySlot.values)
      for (final e in list)
        if (e.kind == TripCylinderEventKind.fill) e,
  ];
  final divers = {
    for (final t in tanks) ?t.diverId,
    for (final u in unlinked) ?u.diverId,
  };

  return TripGasRecord(
    rows: rows,
    slots: slots,
    fillsLogged: fills.length,
    costs: sumByCurrency(
      fills,
      amountOf: (e) => e.isPackage ? null : e.cost,
      currencyOf: (e) => e.currency ?? '',
      fallbackCode: defaultCurrency,
    ),
    packageFills: fills.where((e) => e.isPackage).length,
    unlinked: [...unlinked]
      ..sort(_inDiveOrder((u) => (u.entryTime, u.diveId, u.tankOrder))),
    multipleDivers: divers.length > 1,
  );
}

TripGasRecordRow _row(
  TripGasRecordTank t,
  TripCylinder cylinder,
  List<TripCylinderEvent> events,
  GasModel gasModel,
) {
  final atMillis = t.entryTime.millisecondsSinceEpoch;
  final state = foldCylinderState(
    cylinder: cylinder,
    events: [
      for (final e in events)
        if (e.occurredAt.millisecondsSinceEpoch <= atMillis) e,
    ],
    uses: const [],
  );
  final fill = state.lastFill;
  return TripGasRecordRow(
    tank: t,
    cylinder: cylinder,
    bottleLabel: state.bottleLabel,
    fill: fill,
    fillPressure: fill == null
        ? null
        : fill.pressure ?? cylinder.workingPressure,
    litres: _litres(t, gasModel),
  );
}

/// Free litres breathed from [t]: the gas at its start pressure less the
/// gas at its end, at the tank's mix. Null without a volume or either
/// pressure; an end above the start is 0.
double? _litres(TripGasRecordTank t, GasModel model) {
  final volume = t.volume;
  final start = t.startPressure;
  final end = t.endPressure;
  if (volume == null || start == null || end == null) return null;
  double at(double bar) => gasVolume(
    tankSizeLiters: volume,
    pressureBar: bar,
    o2Percent: t.gasMix.o2,
    hePercent: t.gasMix.he,
    model: model,
  );
  return math.max(0, at(start) - at(end));
}

TripGasRecordSlotTotal _slotTotal(
  TripCylinder cylinder,
  List<TripGasRecordRow> rows,
) {
  final figures = [for (final r in rows) ?r.litres];
  return TripGasRecordSlotTotal(
    cylinder: cylinder,
    dives: {for (final r in rows) r.tank.diveId}.length,
    litres: figures.isEmpty ? null : figures.fold<double>(0, (a, b) => a + b),
    leftOut: {
      for (final r in rows)
        if (r.litres == null) r.tank.diveId,
    }.length,
  );
}

/// Dive order: entry time, then dive, then tank order, the order the
/// repository's queries return.
int Function(T, T) _inDiveOrder<T>((DateTime, String, int) Function(T) key) =>
    (a, b) {
      final (aAt, aDive, aOrder) = key(a);
      final (bAt, bDive, bOrder) = key(b);
      final byTime = aAt.compareTo(bAt);
      if (byTime != 0) return byTime;
      final byDive = aDive.compareTo(bDive);
      return byDive != 0 ? byDive : aOrder.compareTo(bOrder);
    };
