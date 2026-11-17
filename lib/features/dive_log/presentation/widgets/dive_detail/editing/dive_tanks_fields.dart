import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Tanks card's id: its section's name. The card is titled
/// "Cylinders", as its read card is.
final String diveTanksCardId = DiveDetailSectionId.tanks.name;

/// The dive mode, edited on the Tanks card and shown on Details and the
/// header block (issue #4527).
final diveModeField = EditField<Dive, DiveMode>(
  id: 'diveMode',
  cardId: diveTanksCardId,
  alsoShownOn: {DiveDetailSectionId.details.name, diveHeaderCardId},
  read: (dive) => dive.diveMode,
  write: (dive, mode) => dive.copyWith(diveMode: mode),
);

/// One optional value of the Tanks card: null writes its clear flag.
EditField<Dive, V?> _optional<V>(
  String id, {
  required V? Function(Dive dive) read,
  required Dive Function(Dive dive, V value) set,
  required Dive Function(Dive dive) clear,
}) => EditField<Dive, V?>(
  id: id,
  cardId: diveTanksCardId,
  read: read,
  write: (dive, value) => value == null ? clear(dive) : set(dive, value),
);

final diveSetpointLowField = _optional<double>(
  'setpointLow',
  read: (d) => d.setpointLow,
  set: (d, v) => d.copyWith(setpointLow: v),
  clear: (d) => d.copyWith(clearSetpointLow: true),
);

final diveSetpointHighField = _optional<double>(
  'setpointHigh',
  read: (d) => d.setpointHigh,
  set: (d, v) => d.copyWith(setpointHigh: v),
  clear: (d) => d.copyWith(clearSetpointHigh: true),
);

final diveSetpointDecoField = _optional<double>(
  'setpointDeco',
  read: (d) => d.setpointDeco,
  set: (d, v) => d.copyWith(setpointDeco: v),
  clear: (d) => d.copyWith(clearSetpointDeco: true),
);

/// The diluent on a closed circuit, the supply gas on a semi-closed one:
/// both are stored as the dive's diluent.
final diveDiluentGasField = _optional<GasMix>(
  'diluentGas',
  read: (d) => d.diluentGas,
  set: (d, v) => d.copyWith(diluentGas: v),
  clear: (d) => d.copyWith(clearDiluentGas: true),
);

/// The scrubber. One with no type is no scrubber, as the form saves it.
final diveScrubberField = _optional<ScrubberInfo>(
  'scrubber',
  read: (d) => d.scrubber,
  set: (d, v) => d.copyWith(scrubber: v),
  clear: (d) => d.copyWith(clearScrubber: true),
);

final diveLoopVolumeField = _optional<double>(
  'loopVolume',
  read: (d) => d.loopVolume,
  set: (d, v) => d.copyWith(loopVolume: v),
  clear: (d) => d.copyWith(clearLoopVolume: true),
);

final diveScrTypeField = _optional<ScrType>(
  'scrType',
  read: (d) => d.scrType,
  set: (d, v) => d.copyWith(scrType: v),
  clear: (d) => d.copyWith(clearScrType: true),
);

final diveScrInjectionRateField = _optional<double>(
  'scrInjectionRate',
  read: (d) => d.scrInjectionRate,
  set: (d, v) => d.copyWith(scrInjectionRate: v),
  clear: (d) => d.copyWith(clearScrInjectionRate: true),
);

final diveScrAdditionRatioField = _optional<double>(
  'scrAdditionRatio',
  read: (d) => d.scrAdditionRatio,
  set: (d, v) => d.copyWith(scrAdditionRatio: v),
  clear: (d) => d.copyWith(clearScrAdditionRatio: true),
);

final diveScrOrificeSizeField = _optional<String>(
  'scrOrificeSize',
  read: (d) => d.scrOrificeSize,
  set: (d, v) => d.copyWith(scrOrificeSize: v),
  clear: (d) => d.copyWith(clearScrOrificeSize: true),
);

final diveAssumedVo2Field = _optional<double>(
  'assumedVo2',
  read: (d) => d.assumedVo2,
  set: (d, v) => d.copyWith(assumedVo2: v),
  clear: (d) => d.copyWith(clearAssumedVo2: true),
);

final diveLoopO2MinField = _optional<double>(
  'loopO2Min',
  read: (d) => d.loopO2Min,
  set: (d, v) => d.copyWith(loopO2Min: v),
  clear: (d) => d.copyWith(clearLoopO2Min: true),
);

final diveLoopO2MaxField = _optional<double>(
  'loopO2Max',
  read: (d) => d.loopO2Max,
  set: (d, v) => d.copyWith(loopO2Max: v),
  clear: (d) => d.copyWith(clearLoopO2Max: true),
);

final diveLoopO2AvgField = _optional<double>(
  'loopO2Avg',
  read: (d) => d.loopO2Avg,
  set: (d, v) => d.copyWith(loopO2Avg: v),
  clear: (d) => d.copyWith(clearLoopO2Avg: true),
);

/// The dive's cylinders. Their order is the order they are numbered and
/// stored in, so the same cylinders in another order are a change.
final diveTanksField = EditField<Dive, List<DiveTank>>(
  id: 'tanks',
  cardId: diveTanksCardId,
  read: (dive) => dive.tanks,
  write: (dive, tanks) => dive.copyWith(tanks: tanks),
  equals: listEquals,
);

/// What entering CCR filled, so leaving it can take that back.
const _ccrSeedKey = 'ccrSeed';

/// Sets the dive mode.
///
/// Entering CCR fills the low and high setpoints the sitting has empty with
/// [seedLow] and [seedHigh], the diver's defaults (issue #2802), and notes
/// what it filled. Leaving CCR sets back what that filled, unless the diver
/// has changed it since, so OC, CCR, OC is no change. Nothing else moves:
/// a gauge dive keeps its cylinders, hidden, and the values a mode does not
/// use are dropped at Save ([diveSittingApply]).
void setDiveMode(
  EditSession<Dive> session,
  DiveMode mode, {
  required double seedLow,
  required double seedHigh,
}) {
  if (session.isFrozen || session.isDisposed) return;
  final was = session.valueOf(diveModeField);
  if (was == mode) return;
  if (was == DiveMode.ccr) _takeBackSeed(session);
  session.set(diveModeField, mode);
  if (mode != DiveMode.ccr) return;
  final seeded = <String, double>{};
  if (session.valueOf(diveSetpointLowField) == null) {
    session.set(diveSetpointLowField, seedLow);
    seeded[diveSetpointLowField.id] = seedLow;
  }
  if (session.valueOf(diveSetpointHighField) == null) {
    session.set(diveSetpointHighField, seedHigh);
    seeded[diveSetpointHighField.id] = seedHigh;
  }
  session.remember(_ccrSeedKey, seeded);
}

void _takeBackSeed(EditSession<Dive> session) {
  final seeded = session.recall<Map<String, double>>(_ccrSeedKey);
  if (seeded == null) return;
  for (final field in [diveSetpointLowField, diveSetpointHighField]) {
    final value = seeded[field.id];
    if (value != null && session.valueOf(field) == value) {
      session.set(field, field.read(session.stored));
    }
  }
  session.remember(_ccrSeedKey, null);
}

/// [dive] with the rebreather values its mode does not use cleared, as the old
/// dive form's save did: setpoints and loop volume belong to CCR; diluent and
/// scrubber to CCR and SCR; the SCR type, flow, orifice, VO2 and loop O2 values
/// to SCR.
Dive fitRebreatherToMode(Dive dive) {
  final ccr = dive.diveMode == DiveMode.ccr;
  final scr = dive.diveMode == DiveMode.scr;
  return dive.copyWith(
    clearSetpointLow: !ccr,
    clearSetpointHigh: !ccr,
    clearSetpointDeco: !ccr,
    clearLoopVolume: !ccr,
    clearDiluentGas: !ccr && !scr,
    clearScrubber: !ccr && !scr,
    clearScrType: !scr,
    clearScrInjectionRate: !scr,
    clearScrAdditionRatio: !scr,
    clearScrOrificeSize: !scr,
    clearAssumedVo2: !scr,
    clearLoopO2Min: !scr,
    clearLoopO2Max: !scr,
    clearLoopO2Avg: !scr,
  );
}

/// Puts [field]'s value on one dive onto another, typed by the field.
Dive Function(Dive into, Dive from) _carry<V>(EditField<Dive, V> field) =>
    (into, from) => field.write(into, field.read(from));

/// The rebreather values by the modes that use them, as
/// [fitRebreatherToMode] clears them.
final _ccrValues = [
  _carry(diveSetpointLowField),
  _carry(diveSetpointHighField),
  _carry(diveSetpointDecoField),
  _carry(diveLoopVolumeField),
];
final _loopValues = [_carry(diveDiluentGasField), _carry(diveScrubberField)];
final _scrValues = [
  _carry(diveScrTypeField),
  _carry(diveScrInjectionRateField),
  _carry(diveScrAdditionRatioField),
  _carry(diveScrOrificeSizeField),
  _carry(diveAssumedVo2Field),
  _carry(diveLoopO2MinField),
  _carry(diveLoopO2MaxField),
  _carry(diveLoopO2AvgField),
];

/// [merged] with the rebreather values its mode does not use as they are
/// on [stored].
Dive _unusedAsStored(Dive merged, Dive stored) {
  final ccr = merged.diveMode == DiveMode.ccr;
  final scr = merged.diveMode == DiveMode.scr;
  var kept = merged;
  for (final carry in [
    if (!ccr) ..._ccrValues,
    if (!ccr && !scr) ..._loopValues,
    if (!scr) ..._scrValues,
  ]) {
    kept = carry(kept, stored);
  }
  return kept;
}

/// What Save applies to the dive as [stored]: the sitting's changes, then,
/// when the sitting changed the dive mode, [fitRebreatherToMode]. A dive
/// whose mode the diver left alone keeps every value it was stored with:
/// one typed under a mode picked and left again is not this dive's, and is
/// not written.
Dive diveSittingApply(EditSession<Dive> session, Dive stored) {
  final merged = session.applyTo(stored);
  final modeChanged = !diveModeField.same(
    session.valueOf(diveModeField),
    diveModeField.read(session.stored),
  );
  return modeChanged
      ? fitRebreatherToMode(merged)
      : _unusedAsStored(merged, stored);
}
