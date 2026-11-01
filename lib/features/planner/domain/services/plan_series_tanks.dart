import 'package:collection/collection.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';

/// The tanks a repetitive series shares (issue #3565). What a tank is (its
/// size, gas and role) is the series', from the first dive; each dive keeps
/// its own tank ids and its own start pressures, which carry from the dive
/// before unless pinned. Nothing here mutates the series it is given.

/// [series] with every later dive on the first dive's tanks, unless the dive
/// has its own or is on another circuit, whose tanks are not interchangeable.
PlanSeries followSeriesTanks(
  PlanSeries series, {
  required String Function() newId,
}) {
  final first = series.dives.first;
  final dives = [first];
  // For each dive so far: its tank ids, and the first-dive tank each is.
  final roots = <Map<String, String>>[
    {for (final tank in first.state.tanks) tank.id: tank.id},
  ];

  for (final dive in series.dives.skip(1)) {
    final previous = roots.last;
    final own = <String, String>{
      for (final tank in dive.state.tanks)
        tank.id: ?previous[dive.sourceTankIds[tank.id]],
    };
    final takesSeries =
        !dive.settingOverrides.contains(PlanSettingGroup.tanks) &&
        dive.state.mode == first.state.mode;
    if (!takesSeries) {
      dives.add(dive);
      roots.add(own);
      continue;
    }

    final taken = _take(
      dive,
      first.state.tanks,
      own: own,
      keyOf: (tank) => tank.id,
      newId: newId,
    );
    final rootOf = {for (final e in taken.ids.entries) e.value: e.key};
    final previousOf = {for (final e in previous.entries) e.value: e.key};
    dives.add(
      _startFullWithoutLink(
        _withLinks(taken.dive, {
          for (final e in rootOf.entries) e.key: ?previousOf[e.value],
        }),
        first,
        rootOf,
      ),
    );
    roots.add(rootOf);
  }
  return series.copyWith(dives: dives);
}

/// [series] with the first dive taking the tanks of the dive at [index],
/// matched to its own by the first-dive tank each came from.
PlanSeries firstDiveTakesTanks(
  PlanSeries series,
  int index, {
  required String Function() newId,
}) {
  if (index == 0) return series;
  final source = series.dives[index];
  final first = series.dives.first;
  final taken = _take(
    first,
    source.state.tanks,
    own: {for (final tank in first.state.tanks) tank.id: tank.id},
    keyOf: (tank) => _root(series, index, tank.id),
    newId: newId,
  );
  return series.copyWith(dives: [taken.dive, ...series.dives.skip(1)]);
}

/// The first-dive tank the tank [id] of the dive at [index] came from.
String? _root(PlanSeries series, int index, String id) {
  String? current = id;
  for (var i = index; i > 0 && current != null; i--) {
    current = series.dives[i].sourceTankIds[current];
  }
  return current;
}

/// [dive] with the [wanted] tanks, each under the id of the dive's own tank
/// it corresponds to and keeping that tank's start pressure: the one with the
/// same key, else an unclaimed one of the same gas. A wanted tank with
/// neither is new to the dive, and starts as the wanted one does. Tanks left
/// over go, and the profile moves off them.
({PlanSeriesDive dive, Map<String, String> ids}) _take(
  PlanSeriesDive dive,
  List<DiveTank> wanted, {
  required Map<String, String> own,
  required String? Function(DiveTank) keyOf,
  required String Function() newId,
}) {
  final tanks = dive.state.tanks;
  final keys = {for (final tank in wanted) keyOf(tank)};
  final claimed = <String>{};
  final ids = <String, String>{};
  final result = <DiveTank>[];

  for (final tank in wanted) {
    final key = keyOf(tank);
    final match =
        tanks.firstWhereOrNull(
          (t) => !claimed.contains(t.id) && key != null && own[t.id] == key,
        ) ??
        tanks.firstWhereOrNull(
          (t) =>
              !claimed.contains(t.id) &&
              !keys.contains(own[t.id]) &&
              _sameGas(t.gasMix, tank.gasMix),
        );
    final id = match?.id ?? newId();
    claimed.add(id);
    ids[tank.id] = id;
    result.add(
      tank.copyWith(
        id: id,
        startPressure: match == null ? tank.startPressure : match.startPressure,
      ),
    );
  }

  final byId = {for (final tank in result) tank.id: tank};
  final segments = [
    for (final segment in dive.state.segments)
      if (byId[segment.tankId] case final tank?)
        segment.copyWith(gasMix: tank.gasMix)
      else if (_fallback(result, segment.gasMix) case final tank)
        segment.copyWith(tankId: tank.id, gasMix: tank.gasMix),
  ];

  const same = DeepCollectionEquality();
  if (same.equals(result, tanks) &&
      same.equals(segments, dive.state.segments)) {
    return (dive: dive, ids: ids);
  }
  return (
    dive: dive.copyWith(
      state: dive.state.copyWith(
        tanks: result,
        segments: segments,
        isDirty: true,
        updatedAt: DateTime.now(),
      ),
      pinnedTankIds: dive.pinnedTankIds.intersection(claimed),
    ),
    ids: ids,
  );
}

DiveTank _fallback(List<DiveTank> tanks, GasMix gas) =>
    tanks.firstWhereOrNull((tank) => _sameGas(tank.gasMix, gas)) ?? tanks.first;

/// [dive] with each tank the dive before does not have, unless pinned, at
/// the first dive's pressure for it: with nothing to carry, it starts full.
PlanSeriesDive _startFullWithoutLink(
  PlanSeriesDive dive,
  PlanSeriesDive first,
  Map<String, String> rootOf,
) {
  final fills = {for (final t in first.state.tanks) t.id: t.startPressure};
  final tanks = [
    for (final tank in dive.state.tanks)
      if (dive.sourceTankIds[tank.id] == null &&
          !dive.pinnedTankIds.contains(tank.id) &&
          fills[rootOf[tank.id]] != null)
        tank.copyWith(startPressure: fills[rootOf[tank.id]])
      else
        tank,
  ];
  return const DeepCollectionEquality().equals(tanks, dive.state.tanks)
      ? dive
      : dive.copyWith(state: dive.state.copyWith(tanks: tanks));
}

PlanSeriesDive _withLinks(PlanSeriesDive dive, Map<String, String> links) =>
    const MapEquality<String, String>().equals(links, dive.sourceTankIds)
    ? dive
    : dive.copyWith(sourceTankIds: links);

bool _sameGas(GasMix a, GasMix b) =>
    a.roundedO2 == b.roundedO2 && a.roundedHe == b.roundedHe;
