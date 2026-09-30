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
  final ordered = [...tanks]..sort(_byDive);
  final rows = [
    for (final t in ordered)
      if (bySlot[t.tripCylinderId] case final cylinder?)
        _row(t, cylinder, eventsBySlot[cylinder.id] ?? const [], gasModel),
  ];

  final slots = [
    for (final c in cylinders)
      () {
        final mine = rows.where((r) => r.cylinder.id == c.id).toList();
        return TripGasRecordSlotTotal(
          cylinder: c,
          dives: {for (final r in mine) r.tank.diveId}.length,
          litres: mine.fold(0.0, (sum, r) => sum + (r.litres ?? 0)),
          leftOut: mine.where((r) => r.litres == null).length,
        );
      }(),
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
    unlinked: [...unlinked]..sort(_byUnlinked),
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

int _byDive(TripGasRecordTank a, TripGasRecordTank b) {
  final byTime = a.entryTime.compareTo(b.entryTime);
  if (byTime != 0) return byTime;
  final byDive = a.diveId.compareTo(b.diveId);
  return byDive != 0 ? byDive : a.tankOrder.compareTo(b.tankOrder);
}

int _byUnlinked(TripUnlinkedTank a, TripUnlinkedTank b) {
  final byTime = a.entryTime.compareTo(b.entryTime);
  if (byTime != 0) return byTime;
  final byDive = a.diveId.compareTo(b.diveId);
  return byDive != 0 ? byDive : a.tankOrder.compareTo(b.tankOrder);
}
