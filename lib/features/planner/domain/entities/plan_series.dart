import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';

/// The surface interval a dive gets when it is added to a series.
const defaultSeriesSurfaceInterval = Duration(hours: 1);

/// One planned dive in a repetitive series (issue #3565).
///
/// [state] holds the dive's own inputs, its surface interval included
/// ([DivePlanState.surfaceInterval], the gap since the previous dive). What
/// it carries in from the dives before it (tissues, CNS, OTU, tank start
/// pressures) is derived by the series calculator, never edited here.
class PlanSeriesDive extends Equatable {
  final DivePlanState state;

  /// Each tank's counterpart in the previous dive, keyed by this dive's tank
  /// id. A mapped tank starts at its counterpart's end pressure.
  final Map<String, String> sourceTankIds;

  /// Tanks whose start pressure the diver set here (Fill, or typed), so the
  /// previous dive's end pressure is not carried into them.
  final Set<String> pinnedTankIds;

  /// The diver's own name for the dive, such as its site; null = unnamed,
  /// shown by its letter alone. Kept here rather than on [state], whose
  /// name is the whole plan's.
  final String? name;

  const PlanSeriesDive({
    required this.state,
    this.sourceTankIds = const {},
    this.pinnedTankIds = const {},
    this.name,
  });

  PlanSeriesDive copyWith({
    DivePlanState? state,
    Map<String, String>? sourceTankIds,
    Set<String>? pinnedTankIds,
    String? name,
    bool clearName = false,
  }) {
    return PlanSeriesDive(
      state: state ?? this.state,
      sourceTankIds: sourceTankIds ?? this.sourceTankIds,
      pinnedTankIds: pinnedTankIds ?? this.pinnedTankIds,
      name: clearName ? null : (name ?? this.name),
    );
  }

  @override
  List<Object?> get props => [state, sourceTankIds, pinnedTankIds, name];
}

/// An ordered series of planned dives and the one being edited.
class PlanSeries extends Equatable {
  final List<PlanSeriesDive> dives;
  final int selectedIndex;

  const PlanSeries({required this.dives, this.selectedIndex = 0})
    : assert(dives.length > 0);

  /// A plan of one dive: where every plan starts.
  factory PlanSeries.single(DivePlanState state) =>
      PlanSeries(dives: [PlanSeriesDive(state: state)]);

  PlanSeriesDive get selected => dives[selectedIndex];

  /// Whether this is a repetitive series rather than a single dive.
  bool get isSeries => dives.length > 1;

  PlanSeries copyWith({List<PlanSeriesDive>? dives, int? selectedIndex}) {
    return PlanSeries(
      dives: dives ?? this.dives,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }

  @override
  List<Object?> get props => [dives, selectedIndex];
}

/// The letter a planned dive goes by within its series: A, B ... Z, AA, AB.
String seriesDiveLetter(int index) {
  final buffer = StringBuffer();
  var n = index;
  do {
    buffer.writeCharCode(0x41 + n % 26);
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return buffer.toString().split('').reversed.join();
}
