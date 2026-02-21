import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

/// Core dive log entry entity
class Dive extends Equatable {
  final String id;
  final String? diverId;
  final int? diveNumber;
  final DateTime dateTime; // Legacy field, kept for compatibility
  final DateTime? entryTime; // When diver entered water
  final DateTime? exitTime; // When diver exited water
  final Duration? duration; // Bottom time
  final Duration? runtime; // Total runtime (includes descent/ascent)
  final double? maxDepth; // meters
  final double? avgDepth; // meters
  final DiveSite? site;
  final DiveCenter? diveCenter;
  final Trip? trip;
  final String? tripId;
  final List<DiveTank> tanks;
  final List<DiveProfilePoint> profile;
  final List<EquipmentItem> equipment;
  final String notes;
  final List<String> photoIds;
  final List<MarineSighting> sightings;
  final double? waterTemp; // celsius
  final double? airTemp; // celsius
  final Visibility? visibility;
  final String diveTypeId; // References dive_types table
  final DiveTypeEntity? diveType; // Loaded dive type entity (for display)
  final String? buddy;
  final String? diveMaster;
  final int? rating; // 1-5 stars
  // Conditions fields
  final CurrentDirection? currentDirection;
  final CurrentStrength? currentStrength;
  final double? swellHeight; // meters
  final EntryMethod? entryMethod;
  final EntryMethod? exitMethod;
  final WaterType? waterType;
  // Altitude for altitude diving
  final double? altitude; // meters above sea level
  // Surface pressure for altitude/weather corrections
  final double? surfacePressure; // bar (standard ~1.013)
  // Surface interval before this dive
  final Duration? surfaceInterval;
  // Decompression gradient factors
  final int? gradientFactorLow; // GF Lo (0-100)
  final int? gradientFactorHigh; // GF Hi (0-100)
  // Dive computer that logged this dive
  final String? diveComputerModel;
  final String? diveComputerSerial;
  final String? diveComputerFirmware;
  // Weight system fields (legacy single weight - kept for backward compatibility)
  final double? weightAmount; // kg
  final WeightType? weightType;
  // Multiple weight entries per dive (v1.0)
  final List<DiveWeight> weights;
  // Favorites and tags (v1.1/v1.5)
  final bool isFavorite;
  final List<Tag> tags;

  // Dive mode (v1.5) - OC, CCR, or SCR
  final DiveMode diveMode;

  // CCR Setpoints (v1.5) - in bar
  final double? setpointLow; // ~0.7 bar for descent/ascent
  final double? setpointHigh; // ~1.2-1.3 bar for bottom
  final double? setpointDeco; // ~1.3-1.6 bar for deco

  // SCR Configuration (v1.5)
  final ScrType? scrType;
  final double? scrInjectionRate; // L/min at surface (CMF)
  final double? scrAdditionRatio; // e.g., 0.33 for 1:3 (PASCR)
  final String? scrOrificeSize; // '40', '50', '60' (Dolphin)
  final double? assumedVo2; // Assumed O2 consumption L/min

  // Diluent/Supply Gas (v1.5)
  final GasMix? diluentGas;

  // Loop FO2 measurements (v1.5) - for SCR dives
  final double? loopO2Min; // Min loop O2%
  final double? loopO2Max; // Max loop O2%
  final double? loopO2Avg; // Avg loop O2%

  // Shared rebreather fields (v1.5)
  final double? loopVolume; // Loop volume in liters
  final ScrubberInfo? scrubber;

  // Dive planner flag (v1.5)
  final bool isPlanned; // True for planned dives (not yet executed)

  // Training course (v1.5)
  final String? courseId; // FK to training course

  // Wearable integration (v2.0)
  final String? wearableSource; // 'appleWatch', 'garmin', 'suunto'
  final String? wearableId; // Source-specific ID (e.g., HealthKit UUID)

  // User-defined custom fields
  final List<DiveCustomField> customFields;

  const Dive({
    required this.id,
    this.diverId,
    this.diveNumber,
    required this.dateTime,
    this.entryTime,
    this.exitTime,
    this.duration,
    this.runtime,
    this.maxDepth,
    this.avgDepth,
    this.site,
    this.diveCenter,
    this.trip,
    this.tripId,
    this.tanks = const [],
    this.profile = const [],
    this.equipment = const [],
    this.notes = '',
    this.photoIds = const [],
    this.sightings = const [],
    this.waterTemp,
    this.airTemp,
    this.visibility,
    this.diveTypeId = 'recreational',
    this.diveType,
    this.buddy,
    this.diveMaster,
    this.rating,
    this.currentDirection,
    this.currentStrength,
    this.swellHeight,
    this.entryMethod,
    this.exitMethod,
    this.waterType,
    this.altitude,
    this.surfacePressure,
    this.surfaceInterval,
    this.gradientFactorLow,
    this.gradientFactorHigh,
    this.diveComputerModel,
    this.diveComputerSerial,
    this.diveComputerFirmware,
    this.weightAmount,
    this.weightType,
    this.weights = const [],
    this.isFavorite = false,
    this.tags = const [],
    // CCR/SCR fields (v1.5)
    this.diveMode = DiveMode.oc,
    this.setpointLow,
    this.setpointHigh,
    this.setpointDeco,
    this.scrType,
    this.scrInjectionRate,
    this.scrAdditionRatio,
    this.scrOrificeSize,
    this.assumedVo2,
    this.diluentGas,
    this.loopO2Min,
    this.loopO2Max,
    this.loopO2Avg,
    this.loopVolume,
    this.scrubber,
    // Dive planner (v1.5)
    this.isPlanned = false,
    // Training course (v1.5)
    this.courseId,
    // Wearable integration (v2.0)
    this.wearableSource,
    this.wearableId,
    // User-defined custom fields
    this.customFields = const [],
  });

  /// Effective start time of the dive (entryTime if set, otherwise dateTime)
  DateTime get effectiveEntryTime => entryTime ?? dateTime;

  /// Display name for the dive type (uses entity name if loaded, otherwise capitalizes ID)
  String get diveTypeName {
    if (diveType != null) {
      return diveType!.name;
    }
    // Fallback: capitalize the ID (e.g., 'recreational' -> 'Recreational')
    if (diveTypeId.isEmpty) return 'Recreational';
    return diveTypeId[0].toUpperCase() +
        diveTypeId.substring(1).replaceAll('_', ' ');
  }

  /// Calculated duration from entry/exit times
  Duration? get calculatedDuration {
    if (entryTime != null && exitTime != null) {
      return exitTime!.difference(entryTime!);
    }
    return duration;
  }

  /// Total weight from all weight entries
  double get totalWeight => weights.fold(0.0, (sum, w) => sum + w.amountKg);

  // CCR/SCR computed properties

  /// Whether this is a CCR dive
  bool get isCCR => diveMode == DiveMode.ccr;

  /// Whether this is an SCR dive
  bool get isSCR => diveMode == DiveMode.scr;

  /// Whether this is any type of rebreather dive
  bool get isRebreather => isCCR || isSCR;

  /// Get the diluent tank (for CCR dives)
  DiveTank? get diluentTank {
    try {
      return tanks.firstWhere((t) => t.role == TankRole.diluent);
    } catch (_) {
      return null;
    }
  }

  /// Get all bailout tanks
  List<DiveTank> get bailoutTanks =>
      tanks.where((t) => t.role == TankRole.bailout).toList();

  /// Air consumption rate in L/min at surface (Surface Air Consumption)
  /// Calculates total gas consumed across all tanks with valid data.
  double? get sac {
    if (tanks.isEmpty || duration == null || avgDepth == null) return null;

    final minutes = duration!.inSeconds / 60;
    if (minutes <= 0) return null;

    final avgPressureAtm = (avgDepth! / 10) + 1; // Convert depth to ATM

    // Sum gas consumed across all tanks (in liters at surface pressure)
    double totalGasLiters = 0;
    int tanksWithData = 0;

    for (final tank in tanks) {
      if (tank.startPressure == null ||
          tank.endPressure == null ||
          tank.volume == null) {
        continue;
      }

      final pressureUsed = tank.startPressure! - tank.endPressure!;
      if (pressureUsed <= 0) continue;

      // Gas in liters at surface = tank_volume × pressure_used
      // Example: 12L tank, 100 bar used = 1200 liters at surface
      final gasLiters = tank.volume! * pressureUsed;
      totalGasLiters += gasLiters;
      tanksWithData++;
    }

    if (tanksWithData == 0 || totalGasLiters <= 0) return null;

    // SAC in liters/min at surface
    return totalGasLiters / minutes / avgPressureAtm;
  }

  /// Air consumption rate in pressure units per minute (bar/min or psi/min)
  /// This is a simpler calculation that doesn't require tank volume.
  /// It calculates the average pressure drop per minute adjusted for depth.
  double? get sacPressure {
    if (tanks.isEmpty || duration == null || avgDepth == null) return null;

    final minutes = duration!.inSeconds / 60;
    if (minutes <= 0) return null;

    final avgPressureAtm = (avgDepth! / 10) + 1; // Convert depth to ATM

    // Sum pressure consumed across all tanks with data
    double totalPressureUsed = 0;
    int tanksWithData = 0;

    for (final tank in tanks) {
      if (tank.startPressure == null || tank.endPressure == null) {
        continue;
      }

      final pressureUsed = tank.startPressure! - tank.endPressure!;
      if (pressureUsed <= 0) continue;

      totalPressureUsed += pressureUsed;
      tanksWithData++;
    }

    if (tanksWithData == 0 || totalPressureUsed <= 0) return null;

    // SAC in bar/min at surface (average across all tanks)
    return (totalPressureUsed / tanksWithData) / minutes / avgPressureAtm;
  }

  /// Calculate bottom time from dive profile data.
  ///
  /// Bottom time is defined as the time spent at depth, excluding descent and ascent.
  /// This method analyzes the profile to find:
  /// - Descent end: when the diver first reaches the bottom (within threshold of max depth)
  /// - Ascent start: when the diver starts ascending from the bottom
  ///
  /// Returns null if profile data is insufficient for calculation.
  Duration? calculateBottomTimeFromProfile({
    double depthThresholdPercent = 0.85,
  }) {
    if (profile.isEmpty || profile.length < 3) return null;

    // Sort profile by timestamp to ensure correct order
    final sortedProfile = List<DiveProfilePoint>.from(profile)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Find maximum depth
    double maxProfileDepth = 0;
    for (final point in sortedProfile) {
      if (point.depth > maxProfileDepth) {
        maxProfileDepth = point.depth;
      }
    }

    if (maxProfileDepth <= 0) return null;

    // Threshold depth for considering the diver "at the bottom"
    final bottomThreshold = maxProfileDepth * depthThresholdPercent;

    // Find descent end: first point where depth >= threshold
    int? descentEndTimestamp;
    for (final point in sortedProfile) {
      if (point.depth >= bottomThreshold) {
        descentEndTimestamp = point.timestamp;
        break;
      }
    }

    // Find ascent start: last point where depth >= threshold
    int? ascentStartTimestamp;
    for (int i = sortedProfile.length - 1; i >= 0; i--) {
      if (sortedProfile[i].depth >= bottomThreshold) {
        ascentStartTimestamp = sortedProfile[i].timestamp;
        break;
      }
    }

    // Validate we found both points
    if (descentEndTimestamp == null || ascentStartTimestamp == null) {
      return null;
    }

    // Ensure ascent start is after descent end
    if (ascentStartTimestamp <= descentEndTimestamp) return null;

    final bottomTimeSeconds = ascentStartTimestamp - descentEndTimestamp;
    return Duration(seconds: bottomTimeSeconds);
  }

  Dive copyWith({
    String? id,
    String? diverId,
    int? diveNumber,
    DateTime? dateTime,
    DateTime? entryTime,
    DateTime? exitTime,
    Duration? duration,
    Duration? runtime,
    double? maxDepth,
    double? avgDepth,
    DiveSite? site,
    DiveCenter? diveCenter,
    Trip? trip,
    String? tripId,
    List<DiveTank>? tanks,
    List<DiveProfilePoint>? profile,
    List<EquipmentItem>? equipment,
    String? notes,
    List<String>? photoIds,
    List<MarineSighting>? sightings,
    double? waterTemp,
    double? airTemp,
    Visibility? visibility,
    String? diveTypeId,
    DiveTypeEntity? diveType,
    String? buddy,
    String? diveMaster,
    int? rating,
    CurrentDirection? currentDirection,
    CurrentStrength? currentStrength,
    double? swellHeight,
    EntryMethod? entryMethod,
    EntryMethod? exitMethod,
    WaterType? waterType,
    double? altitude,
    double? surfacePressure,
    Duration? surfaceInterval,
    int? gradientFactorLow,
    int? gradientFactorHigh,
    String? diveComputerModel,
    String? diveComputerSerial,
    String? diveComputerFirmware,
    double? weightAmount,
    WeightType? weightType,
    List<DiveWeight>? weights,
    bool? isFavorite,
    List<Tag>? tags,
    // CCR/SCR fields
    DiveMode? diveMode,
    double? setpointLow,
    double? setpointHigh,
    double? setpointDeco,
    ScrType? scrType,
    double? scrInjectionRate,
    double? scrAdditionRatio,
    String? scrOrificeSize,
    double? assumedVo2,
    GasMix? diluentGas,
    double? loopO2Min,
    double? loopO2Max,
    double? loopO2Avg,
    double? loopVolume,
    ScrubberInfo? scrubber,
    // Dive planner
    bool? isPlanned,
    // Training course
    String? courseId,
    // Wearable integration
    String? wearableSource,
    String? wearableId,
    // User-defined custom fields
    List<DiveCustomField>? customFields,
  }) {
    return Dive(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      diveNumber: diveNumber ?? this.diveNumber,
      dateTime: dateTime ?? this.dateTime,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      duration: duration ?? this.duration,
      runtime: runtime ?? this.runtime,
      maxDepth: maxDepth ?? this.maxDepth,
      avgDepth: avgDepth ?? this.avgDepth,
      site: site ?? this.site,
      diveCenter: diveCenter ?? this.diveCenter,
      trip: trip ?? this.trip,
      tripId: tripId ?? this.tripId,
      tanks: tanks ?? this.tanks,
      profile: profile ?? this.profile,
      equipment: equipment ?? this.equipment,
      notes: notes ?? this.notes,
      photoIds: photoIds ?? this.photoIds,
      sightings: sightings ?? this.sightings,
      waterTemp: waterTemp ?? this.waterTemp,
      airTemp: airTemp ?? this.airTemp,
      visibility: visibility ?? this.visibility,
      diveTypeId: diveTypeId ?? this.diveTypeId,
      diveType: diveType ?? this.diveType,
      buddy: buddy ?? this.buddy,
      diveMaster: diveMaster ?? this.diveMaster,
      rating: rating ?? this.rating,
      currentDirection: currentDirection ?? this.currentDirection,
      currentStrength: currentStrength ?? this.currentStrength,
      swellHeight: swellHeight ?? this.swellHeight,
      entryMethod: entryMethod ?? this.entryMethod,
      exitMethod: exitMethod ?? this.exitMethod,
      waterType: waterType ?? this.waterType,
      altitude: altitude ?? this.altitude,
      surfacePressure: surfacePressure ?? this.surfacePressure,
      surfaceInterval: surfaceInterval ?? this.surfaceInterval,
      gradientFactorLow: gradientFactorLow ?? this.gradientFactorLow,
      gradientFactorHigh: gradientFactorHigh ?? this.gradientFactorHigh,
      diveComputerModel: diveComputerModel ?? this.diveComputerModel,
      diveComputerSerial: diveComputerSerial ?? this.diveComputerSerial,
      diveComputerFirmware: diveComputerFirmware ?? this.diveComputerFirmware,
      weightAmount: weightAmount ?? this.weightAmount,
      weightType: weightType ?? this.weightType,
      weights: weights ?? this.weights,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      // CCR/SCR fields
      diveMode: diveMode ?? this.diveMode,
      setpointLow: setpointLow ?? this.setpointLow,
      setpointHigh: setpointHigh ?? this.setpointHigh,
      setpointDeco: setpointDeco ?? this.setpointDeco,
      scrType: scrType ?? this.scrType,
      scrInjectionRate: scrInjectionRate ?? this.scrInjectionRate,
      scrAdditionRatio: scrAdditionRatio ?? this.scrAdditionRatio,
      scrOrificeSize: scrOrificeSize ?? this.scrOrificeSize,
      assumedVo2: assumedVo2 ?? this.assumedVo2,
      diluentGas: diluentGas ?? this.diluentGas,
      loopO2Min: loopO2Min ?? this.loopO2Min,
      loopO2Max: loopO2Max ?? this.loopO2Max,
      loopO2Avg: loopO2Avg ?? this.loopO2Avg,
      loopVolume: loopVolume ?? this.loopVolume,
      scrubber: scrubber ?? this.scrubber,
      // Dive planner
      isPlanned: isPlanned ?? this.isPlanned,
      // Training course
      courseId: courseId ?? this.courseId,
      // Wearable integration
      wearableSource: wearableSource ?? this.wearableSource,
      wearableId: wearableId ?? this.wearableId,
      // User-defined custom fields
      customFields: customFields ?? this.customFields,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    diveNumber,
    dateTime,
    entryTime,
    exitTime,
    duration,
    runtime,
    maxDepth,
    avgDepth,
    site,
    diveCenter,
    trip,
    tripId,
    tanks,
    profile,
    equipment,
    notes,
    photoIds,
    sightings,
    waterTemp,
    airTemp,
    visibility,
    diveTypeId,
    diveType,
    buddy,
    diveMaster,
    rating,
    currentDirection,
    currentStrength,
    swellHeight,
    entryMethod,
    exitMethod,
    waterType,
    altitude,
    surfacePressure,
    surfaceInterval,
    gradientFactorLow,
    gradientFactorHigh,
    diveComputerModel,
    diveComputerSerial,
    diveComputerFirmware,
    weightAmount,
    weightType,
    weights,
    isFavorite,
    tags,
    // CCR/SCR fields
    diveMode,
    setpointLow,
    setpointHigh,
    setpointDeco,
    scrType,
    scrInjectionRate,
    scrAdditionRatio,
    scrOrificeSize,
    assumedVo2,
    diluentGas,
    loopO2Min,
    loopO2Max,
    loopO2Avg,
    loopVolume,
    scrubber,
    // Dive planner
    isPlanned,
    // Training course
    courseId,
    // Wearable integration
    wearableSource,
    wearableId,
    // User-defined custom fields
    customFields,
  ];
}

/// Single point in the dive profile time series
class DiveProfilePoint extends Equatable {
  final int timestamp; // seconds from dive start
  final double depth; // meters
  final double? pressure; // bar
  final double? temperature; // celsius
  final int? heartRate; // bpm
  // CCR/SCR rebreather data (v1.5)
  final double? setpoint; // Current setpoint at this sample (bar)
  final double? ppO2; // Measured/calculated ppO2 (bar)
  // Wearable integration (v2.0)
  final String? heartRateSource; // 'diveComputer', 'appleWatch', 'garmin'

  const DiveProfilePoint({
    required this.timestamp,
    required this.depth,
    this.pressure,
    this.temperature,
    this.heartRate,
    this.setpoint,
    this.ppO2,
    this.heartRateSource,
  });

  DiveProfilePoint copyWith({
    int? timestamp,
    double? depth,
    double? pressure,
    double? temperature,
    int? heartRate,
    double? setpoint,
    double? ppO2,
    String? heartRateSource,
  }) {
    return DiveProfilePoint(
      timestamp: timestamp ?? this.timestamp,
      depth: depth ?? this.depth,
      pressure: pressure ?? this.pressure,
      temperature: temperature ?? this.temperature,
      heartRate: heartRate ?? this.heartRate,
      setpoint: setpoint ?? this.setpoint,
      ppO2: ppO2 ?? this.ppO2,
      heartRateSource: heartRateSource ?? this.heartRateSource,
    );
  }

  @override
  List<Object?> get props => [
    timestamp,
    depth,
    pressure,
    temperature,
    heartRate,
    setpoint,
    ppO2,
    heartRateSource,
  ];
}

/// Per-tank pressure reading at a specific timestamp
/// Used for multi-tank dives with AI transmitters providing
/// continuous pressure data for each tank
class TankPressurePoint extends Equatable {
  final String id;
  final String tankId;
  final int timestamp; // seconds from dive start
  final double pressure; // bar

  const TankPressurePoint({
    required this.id,
    required this.tankId,
    required this.timestamp,
    required this.pressure,
  });

  @override
  List<Object?> get props => [id, tankId, timestamp, pressure];
}

/// Tank configuration for a dive
class DiveTank extends Equatable {
  final String id;
  final String? name; // user-friendly name like "Primary AL80"
  final double? volume; // liters
  final int? workingPressure; // bar - rated pressure
  final int? startPressure; // bar
  final int? endPressure; // bar
  final GasMix gasMix;
  final TankRole role; // back gas, stage, deco, bailout, etc.
  final TankMaterial? material; // aluminum, steel, carbon fiber
  final int order; // for multi-tank ordering
  final String? presetName; // name of preset used (e.g., 'al80', 'hp100')

  const DiveTank({
    required this.id,
    this.name,
    this.volume,
    this.workingPressure,
    this.startPressure,
    this.endPressure,
    this.gasMix = const GasMix(),
    this.role = TankRole.backGas,
    this.material,
    this.order = 0,
    this.presetName,
  });

  /// Pressure consumed during dive
  int? get pressureUsed {
    if (startPressure == null || endPressure == null) return null;
    return startPressure! - endPressure!;
  }

  /// Create a copy with updated fields
  DiveTank copyWith({
    String? id,
    String? name,
    double? volume,
    int? workingPressure,
    int? startPressure,
    int? endPressure,
    GasMix? gasMix,
    TankRole? role,
    TankMaterial? material,
    int? order,
    String? presetName,
    bool clearPresetName = false,
  }) {
    return DiveTank(
      id: id ?? this.id,
      name: name ?? this.name,
      volume: volume ?? this.volume,
      workingPressure: workingPressure ?? this.workingPressure,
      startPressure: startPressure ?? this.startPressure,
      endPressure: endPressure ?? this.endPressure,
      gasMix: gasMix ?? this.gasMix,
      role: role ?? this.role,
      material: material ?? this.material,
      order: order ?? this.order,
      presetName: clearPresetName ? null : (presetName ?? this.presetName),
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
    material,
    order,
    presetName,
  ];
}

/// Gas mixture (Air, Nitrox, Trimix)
class GasMix extends Equatable {
  final double o2; // percentage 0-100
  final double he; // percentage 0-100

  const GasMix({this.o2 = 21.0, this.he = 0.0});

  double get n2 => 100.0 - o2 - he;

  bool get isAir => o2 >= 20 && o2 <= 22 && he == 0;
  bool get isNitrox => o2 > 22 && he == 0;
  bool get isTrimix => he > 0;

  String get name {
    if (isAir) return 'Air';
    if (isTrimix) return 'Tx ${o2.toInt()}/${he.toInt()}';
    if (isNitrox) return 'EAN${o2.toInt()}';
    return '${o2.toInt()}% O2';
  }

  /// Maximum Operating Depth (MOD) at given ppO2
  double mod({double ppO2 = 1.4}) {
    return ((ppO2 / (o2 / 100)) - 1) * 10;
  }

  /// Equivalent Narcotic Depth at given depth
  double end(double depth) {
    final ambientPressure = (depth / 10) + 1;
    final narcoticGas = (n2 + o2) / 100;
    return ((ambientPressure * narcoticGas) - 1) * 10;
  }

  @override
  List<Object?> get props => [o2, he];
}

/// Marine life sighting during a dive
class MarineSighting extends Equatable {
  final String id;
  final String speciesId;
  final String speciesName;
  final int count;
  final String notes;

  const MarineSighting({
    required this.id,
    required this.speciesId,
    required this.speciesName,
    this.count = 1,
    this.notes = '',
  });

  @override
  List<Object?> get props => [id, speciesId, speciesName, count, notes];
}

/// CO₂ scrubber information for rebreather dives (v1.5)
class ScrubberInfo extends Equatable {
  final String type; // e.g., 'Sofnolime 797', 'ExtendAir'
  final int? ratedMinutes; // Manufacturer rated duration
  final int? remainingMinutes; // Estimated remaining at dive start

  const ScrubberInfo({
    required this.type,
    this.ratedMinutes,
    this.remainingMinutes,
  });

  /// Percentage of scrubber life used (0-100)
  double? get usedPercent {
    if (ratedMinutes == null || remainingMinutes == null) return null;
    if (ratedMinutes == 0) return 100.0;
    return ((ratedMinutes! - remainingMinutes!) / ratedMinutes!) * 100;
  }

  /// Percentage of scrubber life remaining (0-100)
  double? get remainingPercent {
    final used = usedPercent;
    if (used == null) return null;
    return 100.0 - used;
  }

  ScrubberInfo copyWith({
    String? type,
    int? ratedMinutes,
    int? remainingMinutes,
  }) {
    return ScrubberInfo(
      type: type ?? this.type,
      ratedMinutes: ratedMinutes ?? this.ratedMinutes,
      remainingMinutes: remainingMinutes ?? this.remainingMinutes,
    );
  }

  @override
  List<Object?> get props => [type, ratedMinutes, remainingMinutes];
}
