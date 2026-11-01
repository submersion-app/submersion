import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';

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

  /// Whether the diver set this dive's start time
  /// ([DivePlanState.startDateTime]), so its surface interval is measured
  /// from it. Otherwise the interval leads and the start follows from it.
  /// A first dive that follows no logged dive has no interval: its start is
  /// whatever the diver gave it.
  final bool fixedStart;

  /// The setting groups this dive keeps its own values for, rather than the
  /// series' (the first dive's). Always empty on the first dive.
  final Set<PlanSettingGroup> settingOverrides;

  const PlanSeriesDive({
    required this.state,
    this.sourceTankIds = const {},
    this.pinnedTankIds = const {},
    this.name,
    this.fixedStart = false,
    this.settingOverrides = const {},
  });

  PlanSeriesDive copyWith({
    DivePlanState? state,
    Map<String, String>? sourceTankIds,
    Set<String>? pinnedTankIds,
    String? name,
    bool clearName = false,
    bool? fixedStart,
    Set<PlanSettingGroup>? settingOverrides,
  }) {
    return PlanSeriesDive(
      state: state ?? this.state,
      sourceTankIds: sourceTankIds ?? this.sourceTankIds,
      pinnedTankIds: pinnedTankIds ?? this.pinnedTankIds,
      name: clearName ? null : (name ?? this.name),
      fixedStart: fixedStart ?? this.fixedStart,
      settingOverrides: settingOverrides ?? this.settingOverrides,
    );
  }

  @override
  List<Object?> get props => [
    state,
    sourceTankIds,
    pinnedTankIds,
    name,
    fixedStart,
    settingOverrides,
  ];
}

/// An ordered series of planned dives and the one being edited, and the
/// logged dives it follows, if any.
class PlanSeries extends Equatable {
  /// The saved series this is, or null until it is saved as one. A single
  /// dive that follows nothing is saved as an ordinary plan and keeps null.
  final String? id;

  /// Whether a dive was added, removed or named since the series was last
  /// saved or opened: changes no single dive's state marks as unsaved.
  final bool structureChanged;

  final List<PlanSeriesDive> dives;
  final int selectedIndex;

  /// The logged dives before the first planned dive; null when the series
  /// follows none.
  final SeriesFollow? follow;

  const PlanSeries({
    required this.dives,
    this.selectedIndex = 0,
    this.follow,
    this.id,
    this.structureChanged = false,
  }) : assert(dives.length > 0);

  /// A plan of one dive: where every plan starts.
  factory PlanSeries.single(DivePlanState state) =>
      PlanSeries(dives: [PlanSeriesDive(state: state)]);

  PlanSeriesDive get selected => dives[selectedIndex];

  /// Whether this is a repetitive series rather than a single dive.
  bool get isSeries => dives.length > 1;

  /// Whether anything here has changed since it was last saved or opened.
  bool get isDirty =>
      structureChanged || dives.any((dive) => dive.state.isDirty);

  /// Whether saving this takes a series row rather than an ordinary plan.
  bool get savesAsSeries => id != null || isSeries || follow != null;

  PlanSeries copyWith({
    List<PlanSeriesDive>? dives,
    int? selectedIndex,
    SeriesFollow? follow,
    bool clearFollow = false,
    String? id,
    bool? structureChanged,
  }) {
    return PlanSeries(
      dives: dives ?? this.dives,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      follow: clearFollow ? null : (follow ?? this.follow),
      id: id ?? this.id,
      structureChanged: structureChanged ?? this.structureChanged,
    );
  }

  @override
  List<Object?> get props => [
    dives,
    selectedIndex,
    follow,
    id,
    structureChanged,
  ];
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
