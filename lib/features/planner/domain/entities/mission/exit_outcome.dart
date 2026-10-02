import 'package:equatable/equatable.dart';

/// A way out for a team whose member's scooter has died. In an overhead,
/// [swim] and [tow] retrace the route; in open water they go straight home.
/// [surface] is open water only: ascend in place, then swim at the surface.
enum MissionExitMode { swim, tow, surface }

/// One way out after a scooter failure, evaluated through the plan engine.
class ExitOutcome extends Equatable {
  final MissionExitMode mode;

  /// The teammate towing, for [MissionExitMode.tow]; null for a swim.
  final String? towerId;
  final bool feasible;

  /// Seconds from the failure point to the end of the exit legs: back along
  /// the route in an overhead, straight to the entry in open water. Zero for
  /// a surface exit, which ascends in place.
  final int exitBottomSeconds;

  /// Time to surface from the end of the exit, from the plan engine.
  final int ttsSeconds;

  /// Surface litres each member breathes from the failure point to the
  /// surface, by member id.
  final Map<String, double> exitLitersByMember;
  final Set<String> gasShortfallMemberIds;
  final Set<String> batteryShortfallMemberIds;

  /// True when a current on some exit leg is at least as fast as the exit
  /// speed, so the team cannot make headway at all. A current the scooters
  /// beat at cruise can still stop a swim or a slow tow.
  final bool blockedByCurrent;

  /// True when the plan engine calls this exit not diveable: it breaks a
  /// critical ppO2, hypoxic, gas density or CNS limit on its own.
  final bool notDiveable;

  /// Surface exit only: seconds at the surface after the ascent, swimming
  /// and, via a shore, walking.
  final int surfaceSeconds;

  /// Surface exit only: metres swum at the surface.
  final double? surfaceSwimM;

  /// Surface exit only: metres walked from the shore to the entry.
  final double? walkM;

  /// Surface exit only: whether it lands on the waypoint's shore exit
  /// rather than swimming straight to the entry.
  final bool viaShore;

  /// Surface exit only: no surface route is within the mission's limit.
  final bool surfaceLimitExceeded;

  /// The computation of this exit threw, so nothing is known about it:
  /// [feasible] is false, but not because of the water, the gas or the
  /// battery.
  final bool failed;

  const ExitOutcome({
    required this.mode,
    this.towerId,
    required this.feasible,
    required this.exitBottomSeconds,
    required this.ttsSeconds,
    required this.exitLitersByMember,
    this.gasShortfallMemberIds = const {},
    this.batteryShortfallMemberIds = const {},
    this.blockedByCurrent = false,
    this.notDiveable = false,
    this.surfaceSeconds = 0,
    this.surfaceSwimM,
    this.walkM,
    this.viaShore = false,
    this.surfaceLimitExceeded = false,
    this.failed = false,
  });

  /// A way out whose computation threw: infeasible, with no time, gas or
  /// shortfall known. Its times are zero and must not be read as times;
  /// read [knownExitSeconds] and [knownTtsSeconds] instead.
  const ExitOutcome.failed({required MissionExitMode mode, String? towerId})
    : this(
        mode: mode,
        towerId: towerId,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: 0,
        exitLitersByMember: const {},
        failed: true,
      );

  /// Total seconds of the way out. Zero, and meaningless, for a [failed]
  /// exit or one the current blocked; anything that ranks or reports exits
  /// reads [knownExitSeconds].
  int get exitSeconds => exitBottomSeconds + ttsSeconds + surfaceSeconds;

  /// [exitSeconds], or null when no way out was travelled: the exit
  /// [failed], or the current blocked it.
  int? get knownExitSeconds => failed || blockedByCurrent ? null : exitSeconds;

  /// [ttsSeconds], or null when no ascent was computed: the exit [failed],
  /// or the current blocked an underwater exit. A blocked surface exit still
  /// knows its ascent in place, which the safe-surface time reads.
  int? get knownTtsSeconds =>
      failed || (blockedByCurrent && mode != MissionExitMode.surface)
      ? null
      : ttsSeconds;

  ExitOutcome copyWith({
    MissionExitMode? mode,
    String? towerId,
    bool clearTowerId = false,
    bool? feasible,
    int? exitBottomSeconds,
    int? ttsSeconds,
    Map<String, double>? exitLitersByMember,
    Set<String>? gasShortfallMemberIds,
    Set<String>? batteryShortfallMemberIds,
    bool? blockedByCurrent,
    bool? notDiveable,
    int? surfaceSeconds,
    double? surfaceSwimM,
    bool clearSurfaceSwimM = false,
    double? walkM,
    bool clearWalkM = false,
    bool? viaShore,
    bool? surfaceLimitExceeded,
    bool? failed,
  }) {
    return ExitOutcome(
      mode: mode ?? this.mode,
      towerId: clearTowerId ? null : (towerId ?? this.towerId),
      feasible: feasible ?? this.feasible,
      exitBottomSeconds: exitBottomSeconds ?? this.exitBottomSeconds,
      ttsSeconds: ttsSeconds ?? this.ttsSeconds,
      exitLitersByMember: exitLitersByMember ?? this.exitLitersByMember,
      gasShortfallMemberIds:
          gasShortfallMemberIds ?? this.gasShortfallMemberIds,
      batteryShortfallMemberIds:
          batteryShortfallMemberIds ?? this.batteryShortfallMemberIds,
      blockedByCurrent: blockedByCurrent ?? this.blockedByCurrent,
      notDiveable: notDiveable ?? this.notDiveable,
      surfaceSeconds: surfaceSeconds ?? this.surfaceSeconds,
      surfaceSwimM: clearSurfaceSwimM
          ? null
          : (surfaceSwimM ?? this.surfaceSwimM),
      walkM: clearWalkM ? null : (walkM ?? this.walkM),
      viaShore: viaShore ?? this.viaShore,
      surfaceLimitExceeded: surfaceLimitExceeded ?? this.surfaceLimitExceeded,
      failed: failed ?? this.failed,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    towerId,
    feasible,
    exitBottomSeconds,
    ttsSeconds,
    exitLitersByMember,
    gasShortfallMemberIds,
    batteryShortfallMemberIds,
    blockedByCurrent,
    notDiveable,
    surfaceSeconds,
    surfaceSwimM,
    walkM,
    viaShore,
    surfaceLimitExceeded,
    failed,
  ];
}
