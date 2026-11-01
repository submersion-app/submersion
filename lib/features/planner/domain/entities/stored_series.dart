import 'package:equatable/equatable.dart';

import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';

/// One dive of a saved repetitive series (issue #3565): its plan and what
/// places it in the series. What it carries in from the dive before is
/// derived when it is opened, never stored.
class StoredSeriesDive extends Equatable {
  final DivePlan plan;

  /// The diver's own name for the dive; null = shown by its letter.
  final String? name;

  /// See `PlanSeriesDive.fixedStart`.
  final bool fixedStart;
  final Set<PlanSettingGroup> settingOverrides;

  /// Each tank's counterpart in the dive before, or in the followed dive for
  /// the first dive, keyed by this dive's tank id.
  final Map<String, String> sourceTankIds;
  final Set<String> pinnedTankIds;

  /// What the saved-plans list shows for the dive.
  final double? summaryMaxDepth;
  final int? summaryRuntimeSeconds;
  final int? summaryTtsSeconds;

  const StoredSeriesDive({
    required this.plan,
    this.name,
    this.fixedStart = false,
    this.settingOverrides = const {},
    this.sourceTankIds = const {},
    this.pinnedTankIds = const {},
    this.summaryMaxDepth,
    this.summaryRuntimeSeconds,
    this.summaryTtsSeconds,
  });

  StoredSeriesDive copyWith({
    DivePlan? plan,
    String? name,
    bool clearName = false,
    bool? fixedStart,
    Set<PlanSettingGroup>? settingOverrides,
    Map<String, String>? sourceTankIds,
    Set<String>? pinnedTankIds,
    double? summaryMaxDepth,
    int? summaryRuntimeSeconds,
    int? summaryTtsSeconds,
  }) {
    return StoredSeriesDive(
      plan: plan ?? this.plan,
      name: clearName ? null : (name ?? this.name),
      fixedStart: fixedStart ?? this.fixedStart,
      settingOverrides: settingOverrides ?? this.settingOverrides,
      sourceTankIds: sourceTankIds ?? this.sourceTankIds,
      pinnedTankIds: pinnedTankIds ?? this.pinnedTankIds,
      summaryMaxDepth: summaryMaxDepth ?? this.summaryMaxDepth,
      summaryRuntimeSeconds:
          summaryRuntimeSeconds ?? this.summaryRuntimeSeconds,
      summaryTtsSeconds: summaryTtsSeconds ?? this.summaryTtsSeconds,
    );
  }

  @override
  List<Object?> get props => [
    plan,
    name,
    fixedStart,
    settingOverrides,
    sourceTankIds,
    pinnedTankIds,
    summaryMaxDepth,
    summaryRuntimeSeconds,
    summaryTtsSeconds,
  ];
}

/// A saved repetitive series: its dives in order and the logged dive it
/// follows, if any.
class StoredSeries extends Equatable {
  final String id;
  final String name;
  final String? diverId;
  final String? followedDiveId;
  final List<StoredSeriesDive> dives;

  const StoredSeries({
    required this.id,
    required this.name,
    this.diverId,
    this.followedDiveId,
    required this.dives,
  });

  StoredSeries copyWith({
    String? id,
    String? name,
    String? diverId,
    String? followedDiveId,
    bool clearFollowedDiveId = false,
    List<StoredSeriesDive>? dives,
  }) {
    return StoredSeries(
      id: id ?? this.id,
      name: name ?? this.name,
      diverId: diverId ?? this.diverId,
      followedDiveId: clearFollowedDiveId
          ? null
          : (followedDiveId ?? this.followedDiveId),
      dives: dives ?? this.dives,
    );
  }

  @override
  List<Object?> get props => [id, name, diverId, followedDiveId, dives];
}
