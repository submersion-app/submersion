import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/services/diver_gas_switch_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/detected_gas_switch_edits.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_editing.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/utils/profile_time_domain.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveGasSwitchSitting');
const _uuid = Uuid();

/// Makes the writer a sitting's gas switch change runs at Save. A
/// provider, so a test can record the write instead of making it.
final diveGasSwitchWriterProvider = Provider<DiverGasSwitchWriter Function()>(
  (ref) => DiverGasSwitchWriter.new,
);

/// Reads the dive's gas switches into [session] from the database, once
/// per sitting ([loadGasSwitches]), through [read].
void loadDiveGasSwitches(EditSession<Dive> session, ProviderRead read) {
  final repository = read(diveRepositoryProvider);
  final writer = read(diveGasSwitchWriterProvider);
  final diveId = session.stored.id;
  loadGasSwitches(
    session,
    read: () async => [
      for (final g in await repository.getGasSwitchesForDive(diveId))
        g.gasSwitch,
    ],
    writer: writer,
  );
}

/// The key of the gas switches' note, and of the change held for them.
const String gasSwitchesKey = 'gasSwitches';

/// The write a change of the gas switches holds, kept from the load.
const _writeKey = 'gasSwitchesWrite';

/// What a sitting holds for the dive's gas switches once they are loaded
/// (issue #32, #4527).
///
/// Gas switches are not part of the dive the sitting edits: they are rows
/// of their own, written by [DiverGasSwitchWriter] after the dive. So they
/// are kept here, and a change to them is held as a change of the Tanks
/// card, run with the sitting's other writes.
@immutable
class SittingGasSwitches {
  const SittingGasSwitches({
    required this.loaded,
    required this.current,
    required this.floor,
    this.depthTouched = const {},
    this.removedWithTank = 0,
  });

  /// As read, in time order: what a save diffs against.
  final List<GasSwitch> loaded;

  /// As the diver has them now.
  final List<GasSwitch> current;

  /// The earliest loaded time, or 0: a switch the dive already holds
  /// before the start never fails the check (#4335).
  final int floor;

  /// Switches whose depth the diver typed: a new time does not refill it.
  final Set<String> depthTouched;

  /// How many switches went with a removed cylinder, for the editor's
  /// notice. The next edit resets it.
  final int removedWithTank;

  SittingGasSwitches copyWith({
    List<GasSwitch>? current,
    Set<String>? depthTouched,
    int? removedWithTank,
  }) => SittingGasSwitches(
    loaded: loaded,
    current: current ?? this.current,
    floor: floor,
    depthTouched: depthTouched ?? this.depthTouched,
    removedWithTank: removedWithTank ?? this.removedWithTank,
  );
}

/// The gas switches the sitting holds, or null before they are loaded.
SittingGasSwitches? sittingGasSwitches(EditSession<Dive> session) =>
    session.recall<SittingGasSwitches>(gasSwitchesKey);

/// The sitting's switches as the profile chart draws them, each with its
/// cylinder as the sitting has it, or null before they load. A switch
/// whose cylinder is gone is left out (issue #4527, plan 6).
List<GasSwitchWithTank>? sittingGasSwitchesWithTanks(
  EditSession<Dive> session,
) {
  final held = sittingGasSwitches(session);
  if (held == null) return null;
  final tanks = {for (final t in session.working.tanks) t.id: t};
  return [
    for (final g in held.current)
      if (tanks[g.tankId] case final tank?)
        GasSwitchWithTank(
          gasSwitch: g,
          tankName: tank.name ?? 'Tank ${tank.order + 1}',
          gasMix: tank.gasMix.name,
          o2Fraction: tank.gasMix.o2 / 100.0,
          heFraction: tank.gasMix.he / 100.0,
        ),
  ];
}

/// Reads the switches that apply to the dive's primary computer
/// (`GasSwitch.shownInEditor`), once per sitting, and keeps the write the
/// edits below hold: through the writer [writer] makes when the write runs
/// (it reaches the database as it is made), with the loaded ids, taking the
/// current list and only the switches whose cylinder is on the dive as it
/// is written. A switch on a cylinder already removed in the sitting is
/// dropped at once ([dropGasSwitchesWithoutTank]). Tracked.
void loadGasSwitches(
  EditSession<Dive> session, {
  required Future<List<GasSwitch>> Function() read,
  required DiverGasSwitchWriter Function() writer,
}) {
  if (!session.firstTime(gasSwitchesKey)) return;
  session.track(() async {
    final List<GasSwitch> all;
    try {
      all = await read();
    } catch (error, stackTrace) {
      _log.warning(
        'Reading the gas switches for a sitting failed',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (session.isDisposed || session.isFrozen) return;
    final computer = session.stored.computerId;
    final loaded = gasSwitchesInTimeOrder(
      all.where((g) => g.shownInEditor(computer)),
    );
    session
      ..remember(
        gasSwitchesKey,
        SittingGasSwitches(
          loaded: loaded,
          current: loaded,
          floor: loaded.fold(
            0,
            (low, g) => g.timestamp < low ? g.timestamp : low,
          ),
        ),
      )
      ..remember(_writeKey, () => _write(session, writer));
    dropGasSwitchesWithoutTank(session);
  }());
}

Future<void> _write(
  EditSession<Dive> session,
  DiverGasSwitchWriter Function() writer,
) {
  final held = sittingGasSwitches(session)!;
  final diveId = session.stored.id;
  final tankIds = {for (final t in session.working.tanks) t.id};
  return writer().save(
    diveId: diveId,
    switches: [
      for (final g in held.current)
        if (tankIds.contains(g.tankId)) g.copyWith(diveId: diveId),
    ],
    loadedIds: {for (final g in held.loaded) g.id},
  );
}

/// Replaces the current list. One equal to what was loaded releases the
/// held change; any other is held as a change of the Tanks card, to run
/// after the dive is written. Does nothing before the load.
void setGasSwitches(
  EditSession<Dive> session,
  List<GasSwitch> next, {
  Set<String>? depthTouched,
  int removedWithTank = 0,
}) {
  if (session.isFrozen || session.isDisposed) return;
  final held = sittingGasSwitches(session);
  final write = session.recall<Future<void> Function()>(_writeKey);
  if (held == null || write == null) return;
  session.remember(
    gasSwitchesKey,
    held.copyWith(
      current: List<GasSwitch>.unmodifiable(next),
      depthTouched: depthTouched,
      removedWithTank: removedWithTank,
    ),
  );
  if (listEquals(next, held.loaded)) {
    session.releaseWrite(gasSwitchesKey);
  } else {
    session.holdChange(gasSwitchesKey, cardId: diveTanksCardId, write: write);
  }
}

/// Drops the switches whose cylinder is no longer on the dive, and counts
/// them for the editor's notice. A switch left pointing at a gone cylinder
/// would be written against a row the save has just deleted. Before the
/// switches are loaded there is nothing to drop: the database removes them
/// with their cylinder.
void dropGasSwitchesWithoutTank(EditSession<Dive> session) {
  final held = sittingGasSwitches(session);
  if (held == null) return;
  final tankIds = {for (final t in session.working.tanks) t.id};
  final kept = [
    for (final g in held.current)
      if (tankIds.contains(g.tankId)) g,
  ];
  final dropped = held.current.length - kept.length;
  if (dropped == 0) return;
  setGasSwitches(session, kept, removedWithTank: dropped);
}

/// The earliest and latest second a switch may fall on, as the old dive form
/// worked them out, from the sitting: the stored profile's last sample, else
/// the runtime, else the bottom time, else exit minus entry; no latest when
/// nothing says how long the dive was. The earliest is the profile's first
/// sample or a loaded switch, when either lies before 0.
({int min, int? max}) gasSwitchTimeLimits(EditSession<Dive> session) =>
    _timeLimits(session, session.valueOf);

/// [gasSwitchTimeLimits] for the dive as stored, before the sitting.
({int min, int? max}) _storedTimeLimits(EditSession<Dive> session) =>
    _timeLimits(session, <V>(EditField<Dive, V> f) => f.read(session.stored));

({int min, int? max}) _timeLimits(
  EditSession<Dive> session,
  V Function<V>(EditField<Dive, V> field) value,
) {
  final profile = session.stored.profile;
  final floor = sittingGasSwitches(session)?.floor ?? 0;
  final profileStart = profileTimeDomain(profile).min;
  final min = profileStart < floor ? profileStart : floor;
  if (profile.isNotEmpty) return (min: min, max: profile.last.timestamp);
  final runtime = value(diveRuntimeField);
  if (runtime != null && runtime > 0) return (min: min, max: runtime.floor());
  final bottom = value(diveBottomTimeField);
  if (bottom != null && bottom > 0) return (min: min, max: bottom.floor());
  final exit = value(diveExitField);
  if (exit != null) {
    final seconds = exit.difference(value(diveEntryField)).inSeconds;
    if (seconds > 0) return (min: min, max: seconds);
  }
  return (min: min, max: null);
}

/// The ids of switches stored already outside the dive's limits or on a
/// second another stored switch shares, and still as loaded. They block
/// nothing: a Notes edit must not wait on an old import's switch. Changed
/// in any way, a switch is the diver's and is checked again.
Set<String> gasSwitchesInvalidAsStored(EditSession<Dive> session) {
  final held = sittingGasSwitches(session);
  if (held == null) return const {};
  final limits = _storedTimeLimits(session);
  final max = limits.max;
  final perSecond = <int, int>{};
  for (final g in held.loaded) {
    perSecond[g.timestamp] = (perSecond[g.timestamp] ?? 0) + 1;
  }
  final invalid = {
    for (final g in held.loaded)
      if (g.timestamp < limits.min ||
          (max != null && g.timestamp > max) ||
          perSecond[g.timestamp]! > 1)
        g.id: g,
  };
  return {
    for (final g in held.current)
      if (invalid[g.id] == g) g.id,
  };
}

/// Whether the editor shows the switches: two breathing cylinders or more,
/// not a gauge dive, not a planned one (`gasSwitchesEditable`).
bool gasSwitchesShown(EditSession<Dive> session) {
  final dive = session.working;
  return gasSwitchesEditable(
    breathingTankCount: breathingTanks(dive.tanks).length,
    mode: dive.diveMode,
    isPlanned: dive.isPlanned,
  );
}

/// False when a shown switch falls outside [gasSwitchTimeLimits], shares a
/// second with another, or names a cylinder not on the dive. The Tanks
/// card's own check: a runtime shortened on the header can make a switch
/// invalid while the Tanks card is closed. A switch stored that way and
/// left alone ([gasSwitchesInvalidAsStored]) is not checked, though its
/// second still counts against one the diver moves onto it.
bool gasSwitchesValid(EditSession<Dive> session) {
  final held = sittingGasSwitches(session);
  if (held == null || !gasSwitchesShown(session)) return true;
  final limits = gasSwitchTimeLimits(session);
  final max = limits.max;
  final tankIds = {for (final t in session.working.tanks) t.id};
  final asStored = gasSwitchesInvalidAsStored(session);
  final perSecond = <int, int>{};
  for (final g in held.current) {
    perSecond[g.timestamp] = (perSecond[g.timestamp] ?? 0) + 1;
  }
  for (final g in held.current) {
    if (asStored.contains(g.id)) continue;
    if (g.timestamp < limits.min || (max != null && g.timestamp > max)) {
      return false;
    }
    if (perSecond[g.timestamp]! > 1) return false;
    if (!tankIds.contains(g.tankId)) return false;
  }
  return true;
}

double? _profileDepth(EditSession<Dive> session, int timestamp) =>
    profileDepthAt(session.stored.profile, timestamp);

/// The cylinder the dive starts on, for the editor's first row.
DiveTank? gasSwitchStartingTank(EditSession<Dive> session) {
  final dive = session.working;
  return startingTankOf(
    tanks: dive.tanks,
    switches: sittingGasSwitches(session)?.current ?? const [],
    diveStart: 0,
    onLoop: dive.diveMode == DiveMode.ccr || dive.diveMode == DiveMode.scr,
  );
}

/// A row changed in the editor. A new time sets the depth from the stored
/// profile, unless the diver typed the depth (`_onGasSwitchChanged`).
void changeGasSwitch(
  EditSession<Dive> session,
  GasSwitch updated,
  GasSwitchField field,
) {
  final held = sittingGasSwitches(session);
  if (held == null) return;
  var touched = held.depthTouched;
  var next = updated;
  if (field == GasSwitchField.depth) {
    touched = {...touched, updated.id};
  } else if (field == GasSwitchField.time &&
      !touched.contains(updated.id) &&
      session.stored.profile.isNotEmpty) {
    // Back at its loaded time, a switch gets its own depth back: a time
    // typed and typed back is no change.
    final loaded = held.loaded.where((g) => g.id == updated.id).firstOrNull;
    final depth = loaded != null && loaded.timestamp == updated.timestamp
        ? loaded.depth
        : _profileDepth(session, updated.timestamp);
    next = depth == null
        ? updated.copyWith(clearDepth: true)
        : updated.copyWith(depth: depth);
  }
  setGasSwitches(session, [
    for (final g in held.current) g.id == next.id ? next : g,
  ], depthTouched: touched);
}

/// A new row a minute after the last switch, within the dive, onto the
/// first breathing cylinder not breathed then (`_addGasSwitch`).
void addGasSwitch(EditSession<Dive> session) {
  final held = sittingGasSwitches(session);
  if (held == null) return;
  var timestamp = 0;
  for (final g in held.current) {
    if (g.timestamp + 60 > timestamp) timestamp = g.timestamp + 60;
  }
  final max = gasSwitchTimeLimits(session).max;
  if (max != null && timestamp > max) timestamp = max;
  final tank = newGasSwitchTank(
    tanks: session.working.tanks,
    switches: held.current,
    timestamp: timestamp,
    startingTankId: gasSwitchStartingTank(session)?.id,
  );
  if (tank == null) return;
  setGasSwitches(
    session,
    gasSwitchesInTimeOrder([
      ...held.current,
      GasSwitch(
        id: _uuid.v4(),
        diveId: session.stored.id,
        timestamp: timestamp,
        tankId: tank.id,
        depth: _profileDepth(session, timestamp),
        createdAt: DateTime.now(),
      ),
    ]),
    depthTouched: held.depthTouched,
  );
}

void removeGasSwitch(EditSession<Dive> session, String id) {
  final held = sittingGasSwitches(session);
  if (held == null) return;
  setGasSwitches(session, [
    for (final g in held.current)
      if (g.id != id) g,
  ], depthTouched: held.depthTouched);
}

/// Applies the edits the cylinder pressures suggest (#4335): re-points the
/// rows it names and adds the switches it found (`_fillDetectedGasSwitches`).
void fillDetectedGasSwitches(EditSession<Dive> session, GasSwitchEdits edits) {
  final held = sittingGasSwitches(session);
  if (held == null) return;
  final now = DateTime.now();
  setGasSwitches(
    session,
    gasSwitchesInTimeOrder([
      for (final g in held.current)
        if (edits.retanked[g.id] case final tankId?)
          g.copyWith(tankId: tankId)
        else
          g,
      for (final missed in edits.added)
        GasSwitch(
          id: _uuid.v4(),
          diveId: session.stored.id,
          timestamp: missed.t,
          tankId: missed.tankId,
          depth: _profileDepth(session, missed.t) ?? missed.depth,
          createdAt: now,
        ),
    ]),
    depthTouched: held.depthTouched,
  );
}

/// A time field was left: the row takes its place in time order, which it
/// must not do while the time is still being typed.
void gasSwitchTimeSettled(EditSession<Dive> session, String id) {
  final held = sittingGasSwitches(session);
  if (held == null) return;
  final ordered = gasSwitchesInTimeOrder(held.current);
  if (listEquals(ordered, held.current)) return;
  setGasSwitches(session, ordered, depthTouched: held.depthTouched);
}
