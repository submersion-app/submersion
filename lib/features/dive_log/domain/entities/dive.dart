import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../../dive_centers/domain/entities/dive_center.dart';
import '../../../dive_sites/domain/entities/dive_site.dart';
import '../../../dive_types/domain/entities/dive_type_entity.dart';
import '../../../equipment/domain/entities/equipment_item.dart';
import '../../../tags/domain/entities/tag.dart';
import '../../../trips/domain/entities/trip.dart';
import 'dive_weight.dart';

/// Core dive log entry entity
class Dive extends Equatable {
  final String id;
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
  // Weight system fields (legacy single weight - kept for backward compatibility)
  final double? weightAmount; // kg
  final WeightType? weightType;
  // Multiple weight entries per dive (v1.0)
  final List<DiveWeight> weights;
  // Favorites and tags (v1.1/v1.5)
  final bool isFavorite;
  final List<Tag> tags;

  const Dive({
    required this.id,
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
    this.weightAmount,
    this.weightType,
    this.weights = const [],
    this.isFavorite = false,
    this.tags = const [],
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
    return diveTypeId[0].toUpperCase() + diveTypeId.substring(1).replaceAll('_', ' ');
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

  /// Air consumption rate in bar/min (Surface Air Consumption)
  double? get sac {
    if (tanks.isEmpty || duration == null || avgDepth == null) return null;
    final tank = tanks.first;
    if (tank.startPressure == null || tank.endPressure == null) return null;

    final pressureUsed = tank.startPressure! - tank.endPressure!;
    final minutes = duration!.inSeconds / 60;
    final avgPressureAtm = (avgDepth! / 10) + 1; // Convert depth to ATM

    return pressureUsed / minutes / avgPressureAtm;
  }

  Dive copyWith({
    String? id,
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
    double? weightAmount,
    WeightType? weightType,
    List<DiveWeight>? weights,
    bool? isFavorite,
    List<Tag>? tags,
  }) {
    return Dive(
      id: id ?? this.id,
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
      weightAmount: weightAmount ?? this.weightAmount,
      weightType: weightType ?? this.weightType,
      weights: weights ?? this.weights,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
        id,
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
        weightAmount,
        weightType,
        weights,
        isFavorite,
        tags,
      ];
}

/// Single point in the dive profile time series
class DiveProfilePoint extends Equatable {
  final int timestamp; // seconds from dive start
  final double depth; // meters
  final double? pressure; // bar
  final double? temperature; // celsius
  final int? heartRate; // bpm

  const DiveProfilePoint({
    required this.timestamp,
    required this.depth,
    this.pressure,
    this.temperature,
    this.heartRate,
  });

  @override
  List<Object?> get props => [timestamp, depth, pressure, temperature, heartRate];
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
      ];
}

/// Gas mixture (Air, Nitrox, Trimix)
class GasMix extends Equatable {
  final double o2; // percentage 0-100
  final double he; // percentage 0-100

  const GasMix({
    this.o2 = 21.0,
    this.he = 0.0,
  });

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
