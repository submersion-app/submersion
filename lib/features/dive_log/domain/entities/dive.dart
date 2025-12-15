import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../../dive_centers/domain/entities/dive_center.dart';
import '../../../dive_sites/domain/entities/dive_site.dart';
import '../../../equipment/domain/entities/equipment_item.dart';

/// Core dive log entry entity
class Dive extends Equatable {
  final String id;
  final int? diveNumber;
  final DateTime dateTime;
  final Duration? duration;
  final double? maxDepth; // meters
  final double? avgDepth; // meters
  final DiveSite? site;
  final DiveCenter? diveCenter;
  final List<DiveTank> tanks;
  final List<DiveProfilePoint> profile;
  final List<EquipmentItem> equipment;
  final String notes;
  final List<String> photoIds;
  final List<MarineSighting> sightings;
  final double? waterTemp; // celsius
  final double? airTemp; // celsius
  final Visibility? visibility;
  final DiveType diveType;
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
  // Weight system fields
  final double? weightAmount; // kg
  final WeightType? weightType;
  final bool? weightBeltUsed;

  const Dive({
    required this.id,
    this.diveNumber,
    required this.dateTime,
    this.duration,
    this.maxDepth,
    this.avgDepth,
    this.site,
    this.diveCenter,
    this.tanks = const [],
    this.profile = const [],
    this.equipment = const [],
    this.notes = '',
    this.photoIds = const [],
    this.sightings = const [],
    this.waterTemp,
    this.airTemp,
    this.visibility,
    this.diveType = DiveType.recreational,
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
    this.weightBeltUsed,
  });

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
    Duration? duration,
    double? maxDepth,
    double? avgDepth,
    DiveSite? site,
    DiveCenter? diveCenter,
    List<DiveTank>? tanks,
    List<DiveProfilePoint>? profile,
    List<EquipmentItem>? equipment,
    String? notes,
    List<String>? photoIds,
    List<MarineSighting>? sightings,
    double? waterTemp,
    double? airTemp,
    Visibility? visibility,
    DiveType? diveType,
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
    bool? weightBeltUsed,
  }) {
    return Dive(
      id: id ?? this.id,
      diveNumber: diveNumber ?? this.diveNumber,
      dateTime: dateTime ?? this.dateTime,
      duration: duration ?? this.duration,
      maxDepth: maxDepth ?? this.maxDepth,
      avgDepth: avgDepth ?? this.avgDepth,
      site: site ?? this.site,
      diveCenter: diveCenter ?? this.diveCenter,
      tanks: tanks ?? this.tanks,
      profile: profile ?? this.profile,
      equipment: equipment ?? this.equipment,
      notes: notes ?? this.notes,
      photoIds: photoIds ?? this.photoIds,
      sightings: sightings ?? this.sightings,
      waterTemp: waterTemp ?? this.waterTemp,
      airTemp: airTemp ?? this.airTemp,
      visibility: visibility ?? this.visibility,
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
      weightBeltUsed: weightBeltUsed ?? this.weightBeltUsed,
    );
  }

  @override
  List<Object?> get props => [
        id,
        diveNumber,
        dateTime,
        duration,
        maxDepth,
        avgDepth,
        site,
        diveCenter,
        tanks,
        profile,
        equipment,
        notes,
        photoIds,
        sightings,
        waterTemp,
        airTemp,
        visibility,
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
        weightBeltUsed,
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
  final double? volume; // liters
  final int? startPressure; // bar
  final int? endPressure; // bar
  final GasMix gasMix;
  final int order; // for multi-tank ordering

  const DiveTank({
    required this.id,
    this.volume,
    this.startPressure,
    this.endPressure,
    this.gasMix = const GasMix(),
    this.order = 0,
  });

  /// Pressure consumed during dive
  int? get pressureUsed {
    if (startPressure == null || endPressure == null) return null;
    return startPressure! - endPressure!;
  }

  @override
  List<Object?> get props => [id, volume, startPressure, endPressure, gasMix, order];
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
