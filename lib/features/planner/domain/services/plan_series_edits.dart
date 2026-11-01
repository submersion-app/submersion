import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';

/// Edits to a repetitive series (issue #3565). Each returns a new series;
/// none mutates the one it is given.

/// Whether a dive can be added after the last one. DPV mission plans are
/// single dives for now.
bool canAppendDive(PlanSeries series) =>
    series.dives.every((dive) => dive.state.mission == null);

/// Whether the plan can be turned into a DPV mission. A series cannot: a
/// mission is a single dive for now.
bool canPlanMission(PlanSeries series) => !series.isSeries;

/// Adds a dive after the last one, copying its settings, profile, tanks and
/// gases under fresh ids, with a [defaultSeriesSurfaceInterval], and selects
/// it. Each new tank is mapped to the tank it was copied from, so it starts
/// at that tank's end pressure.
PlanSeries appendDive(
  PlanSeries series, {
  required String Function() newId,
  DateTime? now,
}) {
  if (!canAppendDive(series)) return series;
  final previous = series.dives.last.state;
  final timestamp = now ?? DateTime.now();

  final tankIds = {for (final tank in previous.tanks) tank.id: newId()};
  final tanks = [
    for (final tank in previous.tanks) tank.copyWith(id: tankIds[tank.id]),
  ];
  final segments = [
    for (final segment in previous.segments)
      segment.copyWith(
        id: newId(),
        tankId: tankIds[segment.tankId] ?? segment.tankId,
      ),
  ];

  final state = previous.copyWith(
    id: newId(),
    tanks: tanks,
    segments: segments,
    surfaceInterval: defaultSeriesSurfaceInterval,
    clearInitialTissueState: true,
    clearInitialExposure: true,
    clearSourceDiveId: true,
    clearLinkedDiveId: true,
    isDirty: false,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  final dive = PlanSeriesDive(
    state: state,
    sourceTankIds: {for (final e in tankIds.entries) e.value: e.key},
  );
  final dives = [...series.dives, dive];
  return series.copyWith(dives: dives, selectedIndex: dives.length - 1);
}

/// Removes the dive at [index]; the last remaining dive is kept.
///
/// The dive after it is re-linked to the dive before it. When the first dive
/// goes, the next one becomes a first dive: nothing is carried into it, so
/// it starts fresh at the tank pressures it was last given. When the series
/// follows a logged dive, the new first dive follows it instead, after its
/// own surface interval.
PlanSeries removeDive(PlanSeries series, int index) {
  if (series.dives.length <= 1 || index < 0 || index >= series.dives.length) {
    return series;
  }
  final dives = [...series.dives];
  final removed = dives.removeAt(index);
  var follow = series.follow;

  if (index < dives.length) {
    final next = dives[index];
    if (index == 0) {
      dives[0] = next.copyWith(
        state: next.state.copyWith(
          clearSurfaceInterval: follow == null,
          clearInitialTissueState: true,
          clearInitialExposure: true,
          // It is the whole plan now, and it has never been saved.
          isDirty: true,
        ),
        // Following, its tanks now carry from the logged tanks the removed
        // dive's carried from.
        sourceTankIds: follow == null
            ? const {}
            : {
                for (final e in next.sourceTankIds.entries)
                  e.key: ?removed.sourceTankIds[e.value],
              },
      );
      // The new first dive's tanks fill to what the removed dive's did.
      if (follow != null) {
        follow = follow.copyWith(
          ownStartPressures: {
            for (final e in next.sourceTankIds.entries)
              e.key: ?follow.ownStartPressures[e.value],
          },
        );
      }
    } else {
      dives[index] = next.copyWith(
        sourceTankIds: {
          for (final e in next.sourceTankIds.entries)
            e.key: ?removed.sourceTankIds[e.value],
        },
      );
    }
  }

  final selected = series.selectedIndex;
  // Removing the selected dive selects the one before it.
  final newSelected = selected > index
      ? selected - 1
      : selected == index
      ? (index - 1).clamp(0, dives.length - 1)
      : selected;
  return PlanSeries(dives: dives, selectedIndex: newSelected, follow: follow);
}

/// Selects the dive at [index], clamped to the series.
PlanSeries selectDive(PlanSeries series, int index) =>
    series.copyWith(selectedIndex: index.clamp(0, series.dives.length - 1));

/// Names the dive at [index]. The name is trimmed; a blank one clears it.
PlanSeries renameDive(PlanSeries series, int index, String name) {
  final dive = series.dives[index];
  final trimmed = name.trim();
  return _replace(
    series,
    index,
    trimmed.isEmpty
        ? dive.copyWith(clearName: true)
        : dive.copyWith(name: trimmed),
  );
}

/// Sets when the dive at [index] starts, as clock digits stamped UTC like
/// the dive log's times; null clears it. A start fixes the dive's time, so
/// its surface interval is measured from it; with none, the interval leads
/// again.
PlanSeries setDiveStart(PlanSeries series, int index, DateTime? start) {
  final dive = series.dives[index];
  return _replace(
    series,
    index,
    dive.copyWith(
      state: dive.state.copyWith(
        startDateTime: start,
        clearStartDateTime: start == null,
        isDirty: true,
        updatedAt: DateTime.now(),
      ),
      fixedStart: start != null,
    ),
  );
}

/// Lets the surface interval of the dive at [index] lead: the diver set the
/// interval, so the start follows from it.
PlanSeries anchorInterval(PlanSeries series, int index) {
  final dive = series.dives[index];
  if (!dive.fixedStart) return series;
  return _replace(series, index, dive.copyWith(fixedStart: false));
}

/// Names the whole plan: every dive of the series carries its name.
PlanSeries setPlanName(PlanSeries series, String name) => series.copyWith(
  dives: [
    for (final dive in series.dives)
      dive.copyWith(state: dive.state.copyWith(name: name)),
  ],
);

/// Replaces the inputs of the dive at [index] with an edited [state].
///
/// With [pinTypedPressures], a tank whose start pressure the edit changed is
/// pinned: the diver typed it, so it is no longer carried.
PlanSeries updateDiveState(
  PlanSeries series,
  int index,
  DivePlanState state, {
  bool pinTypedPressures = true,
}) {
  final dive = series.dives[index];
  var pinned = dive.pinnedTankIds;
  if (pinTypedPressures) {
    final before = {
      for (final tank in dive.state.tanks) tank.id: tank.startPressure,
    };
    final typed = {
      for (final tank in state.tanks)
        if (before.containsKey(tank.id) &&
            before[tank.id] != tank.startPressure)
          tank.id,
    };
    if (typed.isNotEmpty) pinned = {...pinned, ...typed};
  }
  return _replace(
    series,
    index,
    dive.copyWith(state: state, pinnedTankIds: pinned),
  );
}

/// The pressure the tank [tankId] of the dive at [index] is filled to: its
/// start pressure in the dive the series first carried it in, falling back
/// to its rated working pressure. A first dive that follows a logged dive
/// fills to its own pressure from before it followed it. Null for a tank
/// the dive does not have.
double? fullPressureFor(PlanSeries series, int index, String tankId) {
  var diveIndex = index;
  var id = tankId;
  DiveTank? tank = _tank(series.dives[diveIndex].state, id);
  if (tank == null) return null;
  while (diveIndex > 0) {
    final source = series.dives[diveIndex].sourceTankIds[id];
    if (source == null) break;
    final earlier = _tank(series.dives[diveIndex - 1].state, source);
    if (earlier == null) break;
    diveIndex--;
    id = source;
    tank = earlier;
  }
  final follow = series.follow;
  if (diveIndex == 0 && follow != null) {
    return follow.ownStartPressures[id] ??
        tank!.workingPressure ??
        tank!.startPressure;
  }
  return tank!.startPressure ?? tank.workingPressure;
}

/// The series following the logged dives in [follow], the first dive after
/// [surfaceInterval].
///
/// The first dive takes the followed dive's tanks, under fresh ids from
/// [newId], each linked to the logged tank it copies so it starts at that
/// tank's end pressure. Their own pressure, for Fill and [unfollow], is the
/// logged tank's start pressure. The profile, and the next dive's tank
/// links, move from each old tank to the new one of the same gas, else to
/// the first. A followed dive with no tanks leaves the plan's own.
PlanSeries followDive(
  PlanSeries series,
  SeriesFollow follow, {
  required Duration surfaceInterval,
  required String Function() newId,
}) {
  final first = series.dives.first;
  final dives = [...series.dives];
  if (follow.endTanks.isEmpty) {
    final kept = series.follow?.ownStartPressures ?? const <String, double>{};
    final own = {
      for (final tank in first.state.tanks)
        tank.id: ?(kept[tank.id] ?? tank.startPressure),
    };
    dives[0] = first.copyWith(
      state: first.state.copyWith(
        surfaceInterval: surfaceInterval,
        isDirty: true,
        updatedAt: DateTime.now(),
      ),
      sourceTankIds: const {},
    );
    return series.copyWith(
      dives: dives,
      follow: follow.copyWith(ownStartPressures: own),
    );
  }

  final logged = [...follow.endTanks]
    ..sort((a, b) => a.order.compareTo(b.order));
  final tanks = [
    for (final tank in logged)
      DiveTank(
        id: newId(),
        name: tank.name,
        volume: tank.volume,
        workingPressure: tank.workingPressure,
        startPressure: tank.startPressure ?? tank.workingPressure,
        gasMix: tank.gasMix,
        role: tank.role,
        material: tank.material,
        order: tank.order,
        presetName: tank.presetName,
      ),
  ];
  final replaced = {
    for (final old in first.state.tanks)
      old.id: tanks.firstWhere(
        (t) => _sameGas(t.gasMix, old.gasMix),
        orElse: () => tanks.first,
      ),
  };
  final segments = [
    for (final segment in first.state.segments)
      if (replaced[segment.tankId] case final tank?)
        segment.copyWith(tankId: tank.id, gasMix: tank.gasMix)
      else
        segment,
  ];
  dives[0] = first.copyWith(
    state: first.state.copyWith(
      surfaceInterval: surfaceInterval,
      tanks: tanks,
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    ),
    sourceTankIds: {
      for (var i = 0; i < tanks.length; i++) tanks[i].id: logged[i].id,
    },
    pinnedTankIds: const {},
  );
  if (dives.length > 1) {
    final next = dives[1];
    dives[1] = next.copyWith(
      sourceTankIds: {
        for (final e in next.sourceTankIds.entries)
          e.key: ?replaced[e.value]?.id,
      },
    );
  }
  return series.copyWith(
    dives: dives,
    follow: follow.copyWith(
      ownStartPressures: {
        for (final tank in tanks) tank.id: ?tank.startPressure,
      },
    ),
  );
}

bool _sameGas(GasMix a, GasMix b) =>
    a.roundedO2 == b.roundedO2 && a.roundedHe == b.roundedHe;

/// The series no longer following a logged dive: the first dive drops what
/// it carried in and its interval, and its tanks that were carried go back
/// to their own pressures. Tanks taken from the followed dive stay.
PlanSeries unfollow(PlanSeries series) {
  final follow = series.follow;
  if (follow == null) return series;
  final first = series.dives.first;
  final tanks = [
    for (final tank in first.state.tanks)
      if (!first.pinnedTankIds.contains(tank.id) &&
          follow.ownStartPressures[tank.id] != null)
        tank.copyWith(startPressure: follow.ownStartPressures[tank.id])
      else
        tank,
  ];
  final dives = [...series.dives];
  dives[0] = first.copyWith(
    state: first.state.copyWith(
      tanks: tanks,
      clearSurfaceInterval: true,
      clearInitialTissueState: true,
      clearInitialExposure: true,
      isDirty: true,
      updatedAt: DateTime.now(),
    ),
    sourceTankIds: const {},
  );
  return series.copyWith(dives: dives, clearFollow: true);
}

/// The tanks of the dive at [index] below their fill, with the pressure Fill
/// takes each to.
Map<String, double> fillPressures(PlanSeries series, int index) => {
  for (final tank in series.dives[index].state.tanks)
    if (fullPressureFor(series, index, tank.id) case final full?
        when (tank.startPressure ?? 0) < full)
      tank.id: full,
};

/// Fills one tank of the dive at [index] and pins it.
PlanSeries fillTank(PlanSeries series, int index, String tankId) =>
    _fill(series, index, {tankId});

/// Fills every tank of the dive at [index] below its fill and pins them. A
/// tank set above its fill keeps its pressure.
PlanSeries fillAllTanks(PlanSeries series, int index) =>
    _fill(series, index, fillPressures(series, index).keys.toSet());

PlanSeries _fill(PlanSeries series, int index, Set<String> tankIds) {
  final dive = series.dives[index];
  final tanks = [
    for (final tank in dive.state.tanks)
      if (tankIds.contains(tank.id))
        tank.copyWith(
          startPressure:
              fullPressureFor(series, index, tank.id) ?? tank.startPressure,
        )
      else
        tank,
  ];
  return _replace(
    series,
    index,
    dive.copyWith(
      state: dive.state.copyWith(
        tanks: tanks,
        isDirty: true,
        updatedAt: DateTime.now(),
      ),
      pinnedTankIds: {...dive.pinnedTankIds, ...tankIds},
    ),
  );
}

DiveTank? _tank(DivePlanState state, String id) {
  for (final tank in state.tanks) {
    if (tank.id == id) return tank;
  }
  return null;
}

PlanSeries _replace(PlanSeries series, int index, PlanSeriesDive dive) {
  final dives = [...series.dives];
  dives[index] = dive;
  return series.copyWith(dives: dives);
}
