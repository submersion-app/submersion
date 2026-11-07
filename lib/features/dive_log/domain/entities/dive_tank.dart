import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/features/dive_log/domain/entities/tank_extra_regulators.dart';

/// Tank configuration for a dive
class DiveTank extends Equatable {
  final String id;
  final String? name; // user-friendly name like "Primary AL80"
  final double? volume; // liters
  final double? workingPressure; // bar - rated pressure
  final double? startPressure; // bar
  final double? endPressure; // bar
  final GasMix gasMix;
  final TankRole role; // back gas, stage, deco, bailout, etc.

  /// Where [role] came from when no person chose it (issue #2595): a role
  /// the computer read off the transmitter's name is unconfirmed, and the
  /// transmitter registry may replace it. Null once the diver or the
  /// registry set the role. Downloads, re-parses and the registry write it;
  /// [DiveRepository.updateDive] clears it when the role changes.
  final TankRoleSource? roleSource;
  final TankMaterial? material; // aluminum, steel, carbon fiber
  final int order; // for multi-tank ordering
  final String? presetName; // name of preset used (e.g., 'al80', 'hp100')

  /// The dive computer this tank was attributed to, for multi-source dives.
  /// Null means the tank is unattributed (single-source dive, or a manually
  /// entered/edited tank not tied to a specific computer).
  final String? computerId;

  /// Serial number of the air-integration transmitter that reported this
  /// tank's pressures, as the dive computer logged it. Null for manually
  /// entered tanks and for computers that do not report one.
  ///
  /// This is the cylinder's physical identity across computers: two logs of
  /// the same dive whose tanks carry the same serial were read from the same
  /// transmitter, whatever gas mix each computer had programmed.
  final String? transmitterSerial;

  /// The data source this tank row came from (v251, issue #2716), so two
  /// consolidated sources that name no computer keep their copies of one
  /// cylinder apart. Null means the dive's primary source. Read-only
  /// projection, like [computerId]: the import, download and source-moving
  /// paths write it, and edit flows never do.
  final String? sourceId;

  /// Parsed tank index this row's computer-owned data comes from (v200). Null
  /// on rows from before v200 means "same as order"; -1 (kNoSourceTankIndex
  /// in tank_source_index.dart) means the row takes no parsed tank.
  /// Computer-owned identity, like [computerId] and [transmitterSerial]:
  /// user edits never rewrite it.
  final int? sourceTankIndex;

  /// The other computers on a consolidated dive that logged this same
  /// cylinder (v260): consolidation keeps one row per physical cylinder,
  /// attributed to [computerId], and lists here the computers merged into
  /// it. Empty when that was recorded and found nobody; null when it was
  /// never recorded (tank_shared_computers.dart). Computer-owned identity,
  /// like [computerId]: user edits never rewrite it.
  final List<String>? sharedComputerIds;

  /// The regulator this cylinder was breathed through (v202), so high-O2
  /// contact reaches the regulator's service clocks. User-authored: the
  /// tank editor sets it and downloads never touch it.
  final String? regulatorEquipmentId;

  /// The regulators on this cylinder after [regulatorEquipmentId] (v312,
  /// issue #3375): a twin valve or twin set carries more than one, and each
  /// counts as on the dive. User-authored like [regulatorEquipmentId].
  /// The repository normalises the pair on write
  /// (tank_extra_regulators.dart), so a copy here may hold extras with no
  /// first until it is saved.
  final List<String> extraRegulatorIds;

  /// The trip cylinder slot this tank was breathed from (v232, issue
  /// #2325). User-authored: the tank editor sets it and downloads never
  /// touch it. Meaningless outside the dive's trip, so the repository drops
  /// it when the dive moves.
  final String? tripCylinderId;

  /// The passport id of the tagged cylinder this tank was filled from (v287,
  /// issue #2650): set by a scan or a pick of a cylinder that has one,
  /// cleared by a preset or a trip slot. An identity, not a link, so a
  /// rental with no gear row still counts its uses. User-authored like
  /// [tripCylinderId]: downloads never touch it.
  final String? passportId;

  /// The passport id of the second cylinder when this tank is a twin set
  /// picked from a linked cylinder (issue #4242): [passportId] names the
  /// cylinder picked, this its partner, so both passports count the dive.
  /// Set and cleared with [passportId]; a later swap never rewrites it.
  final String? twinPassportId;

  /// The gear item this cylinder is (the `dive_tanks.equipment_id` link the
  /// transmitter registry writes when a serial is assigned to an item).
  /// Read-only on the domain side: edit flows rebuild the tank field by
  /// field and never write it, like [computerId], so a rebuild that forgot
  /// it cannot wipe what the registry recorded.
  final String? equipmentId;

  /// How long this cylinder was breathed, as the source log recorded it
  /// (v259, issue #1496). MacDive logs one per tank with no gas-switch
  /// times, so it says how long but not when. Per-cylinder SAC uses it as
  /// the breathing time when the dive has no gas switches. Import-owned,
  /// like [transmitterSerial]: edit flows never write it.
  final Duration? usageDuration;

  /// Deco gas-switch depth override in meters (planning only); null = auto
  /// (MOD at the deco pO2). Subsurface per-cylinder "Deco switch at", v120.
  /// Unused for logged-dive tanks.
  final double? decoSwitchDepth;

  /// Whether this cylinder also doubles as travel gas: breathed during the
  /// descent (typically to bypass a hypoxic back gas's minimum depth) before
  /// switching to its primary role's gas. Independent of [role] -- a stage,
  /// deco, or diluent cylinder can be flagged as travel gas without changing
  /// what it is otherwise used for. Planning only; unused for logged-dive
  /// tanks.
  final bool isTravelGas;

  const DiveTank({
    required this.id,
    this.name,
    this.volume,
    this.workingPressure,
    this.startPressure,
    this.endPressure,
    this.gasMix = const GasMix(),
    this.role = TankRole.backGas,
    this.roleSource,
    this.material,
    this.order = 0,
    this.presetName,
    this.computerId,
    this.transmitterSerial,
    this.sourceId,
    this.sourceTankIndex,
    this.sharedComputerIds,
    this.regulatorEquipmentId,
    this.extraRegulatorIds = const [],
    this.tripCylinderId,
    this.passportId,
    this.twinPassportId,
    this.equipmentId,
    this.usageDuration,
    this.decoSwitchDepth,
    this.isTravelGas = false,
  });

  /// Every regulator on this cylinder: the first, then the extras.
  List<String> get regulatorIds => [
    ?regulatorEquipmentId,
    ...extraRegulatorIds,
  ];

  /// A copy carrying [ids] as its regulators, normalised the way the
  /// repository stores them: the first id is the first regulator.
  DiveTank withRegulators(List<String> ids) {
    final regs = normalizeTankRegulators(null, ids);
    return copyWith(
      regulatorEquipmentId: regs.first,
      clearRegulatorEquipmentId: regs.first == null,
      extraRegulatorIds: regs.extras,
    );
  }

  /// Whether [computer] breathed this cylinder: it owns it, shares it, or
  /// the tank belongs to the whole dive (unattributed).
  bool isUsedBy(String computer) =>
      computerId == null ||
      computerId == computer ||
      (sharedComputerIds?.contains(computer) ?? false);

  /// Pressure consumed during dive
  double? get pressureUsed {
    if (startPressure == null || endPressure == null) return null;
    return startPressure! - endPressure!;
  }

  /// Create a copy with updated fields
  DiveTank copyWith({
    String? id,
    String? name,
    bool clearName = false,
    double? volume,
    double? workingPressure,
    double? startPressure,
    double? endPressure,
    GasMix? gasMix,
    TankRole? role,
    TankRoleSource? roleSource,
    bool clearRoleSource = false,
    TankMaterial? material,
    int? order,
    String? presetName,
    bool clearPresetName = false,
    String? computerId,
    String? transmitterSerial,
    bool clearTransmitterSerial = false,
    String? sourceId,
    int? sourceTankIndex,
    bool clearSourceTankIndex = false,
    List<String>? sharedComputerIds,
    String? regulatorEquipmentId,
    List<String>? extraRegulatorIds,
    String? equipmentId,
    Duration? usageDuration,
    bool clearUsageDuration = false,
    bool clearRegulatorEquipmentId = false,
    bool clearMaterial = false,
    String? tripCylinderId,
    bool clearTripCylinderId = false,
    String? passportId,
    bool clearPassportId = false,
    String? twinPassportId,
    bool clearTwinPassportId = false,
    double? decoSwitchDepth,
    bool clearDecoSwitchDepth = false,
    bool? isTravelGas,
  }) {
    return DiveTank(
      id: id ?? this.id,
      name: clearName ? null : (name ?? this.name),
      volume: volume ?? this.volume,
      workingPressure: workingPressure ?? this.workingPressure,
      startPressure: startPressure ?? this.startPressure,
      endPressure: endPressure ?? this.endPressure,
      gasMix: gasMix ?? this.gasMix,
      role: role ?? this.role,
      roleSource: clearRoleSource ? null : (roleSource ?? this.roleSource),
      material: clearMaterial ? null : (material ?? this.material),
      order: order ?? this.order,
      presetName: clearPresetName ? null : (presetName ?? this.presetName),
      computerId: computerId ?? this.computerId,
      transmitterSerial: clearTransmitterSerial
          ? null
          : (transmitterSerial ?? this.transmitterSerial),
      sourceId: sourceId ?? this.sourceId,
      sourceTankIndex: clearSourceTankIndex
          ? null
          : (sourceTankIndex ?? this.sourceTankIndex),
      sharedComputerIds: sharedComputerIds ?? this.sharedComputerIds,
      regulatorEquipmentId: clearRegulatorEquipmentId
          ? null
          : (regulatorEquipmentId ?? this.regulatorEquipmentId),
      extraRegulatorIds: extraRegulatorIds ?? this.extraRegulatorIds,
      tripCylinderId: clearTripCylinderId
          ? null
          : (tripCylinderId ?? this.tripCylinderId),
      passportId: clearPassportId ? null : (passportId ?? this.passportId),
      twinPassportId: clearTwinPassportId
          ? null
          : (twinPassportId ?? this.twinPassportId),
      equipmentId: equipmentId ?? this.equipmentId,
      usageDuration: clearUsageDuration
          ? null
          : (usageDuration ?? this.usageDuration),
      decoSwitchDepth: clearDecoSwitchDepth
          ? null
          : (decoSwitchDepth ?? this.decoSwitchDepth),
      isTravelGas: isTravelGas ?? this.isTravelGas,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    volume,
    workingPressure,
    startPressure,
    endPressure,
    gasMix,
    role,
    roleSource,
    material,
    order,
    presetName,
    computerId,
    transmitterSerial,
    sourceId,
    sourceTankIndex,
    sharedComputerIds,
    regulatorEquipmentId,
    extraRegulatorIds,
    equipmentId,
    tripCylinderId,
    passportId,
    twinPassportId,
    usageDuration,
    decoSwitchDepth,
    isTravelGas,
  ];
}

/// Gas mixture (Air, Nitrox, Trimix)
class GasMix extends Equatable {
  final double o2; // percentage 0-100
  final double he; // percentage 0-100

  const GasMix({this.o2 = 21.0, this.he = 0.0});

  double get n2 => 100.0 - o2 - he;
  int get roundedO2 => o2.round();
  int get roundedHe => he.round();

  bool get isAir => o2 >= 20 && o2 <= 22 && he == 0;
  bool get isNitrox => o2 > 22 && he == 0;
  bool get isTrimix => he > 0;
  bool get isOxygen => o2 >= 99 && he == 0;

  String get name {
    if (isAir) return 'Air';
    if (isTrimix) return 'Tx $roundedO2/$roundedHe';
    if (isOxygen) return 'O2';
    if (isNitrox) return 'EAN$roundedO2';
    return '$roundedO2% O2';
  }

  /// Maximum Operating Depth (MOD) at given ppO2, exact and unrounded.
  ///
  /// Round it down for display with `UnitFormatter.formatDepthFloor`.
  double mod({double ppO2 = 1.4}) =>
      maxOperatingDepthMeters(o2 / 100, maxPpO2: ppO2);

  /// Equivalent Narcotic Depth at given depth.
  ///
  /// When [o2Narcotic] is true, all gases except He are narcotic.
  /// When false, only N2 is narcotic (compared against the air N2 baseline).
  double end(double depth, {bool o2Narcotic = true}) {
    final ambientPressure = (depth / 10) + 1;
    if (o2Narcotic) {
      final narcoticFraction = (100.0 - he) / 100.0;
      return ((ambientPressure * narcoticFraction) - 1) * 10;
    } else {
      final n2Fraction = n2 / 100.0;
      return ((ambientPressure * n2Fraction / airN2Fraction) - 1) * 10;
    }
  }

  /// Maximum Narcotic Depth for this gas at a given END limit.
  ///
  /// Returns the deepest depth where the narcotic effect stays
  /// at or below [endLimit] meters equivalent.
  double mnd({double endLimit = 30.0, bool o2Narcotic = true}) {
    final targetPressure = (endLimit / 10) + 1;
    if (o2Narcotic) {
      final narcoticFraction = (100.0 - he) / 100.0;
      if (narcoticFraction <= 0) return double.infinity;
      final maxPressure = targetPressure / narcoticFraction;
      return (maxPressure - 1) * 10;
    } else {
      final n2Fraction = n2 / 100.0;
      if (n2Fraction <= 0) return double.infinity;
      final maxPressure = targetPressure * airN2Fraction / n2Fraction;
      return (maxPressure - 1) * 10;
    }
  }

  /// Calculate He% needed to achieve a target MND at a given O2%.
  ///
  /// Returns He percentage (0-100), clamped to valid range.
  static double heForMnd(
    double targetMnd,
    double o2, {
    double endLimit = 30.0,
    bool o2Narcotic = true,
  }) {
    final targetPressure = (endLimit / 10) + 1;
    final maxPressure = (targetMnd / 10) + 1;

    final he = o2Narcotic
        ? (1 - targetPressure / maxPressure) * 100
        : 100 - o2 - (targetPressure * airN2Fraction / maxPressure * 100);

    return he.clamp(0.0, 100 - o2);
  }

  @override
  List<Object?> get props => [o2, he];
}
