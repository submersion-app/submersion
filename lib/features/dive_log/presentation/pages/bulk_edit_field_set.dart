import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// The universe of gated scalar fields in the bulk-edit form. Collections
/// (tags/equipment/buddies/tanks/weights/sightings) are handled separately via
/// [BulkCollectionType] + the engine's collection ops.
enum BulkField {
  diveCenter,
  trip,
  course,
  diveType,
  rating,
  isFavorite,
  waterType,
  visibility,
  currentDirection,
  currentStrength,
  swellHeight,
  entryMethod,
  exitMethod,
  altitude,
  surfacePressure,
  surfaceInterval,
  gradientFactorLow,
  gradientFactorHigh,
  decoAlgorithm,
  decoConservatism,
  diveComputerModel,
  windSpeed,
  windDirection,
  cloudCover,
  precipitation,
  humidity,
  weatherDescription,
  diveMode,
  setpointLow,
  setpointHigh,
  setpointDeco,
  diluentGas,
  scrubberType,
  scrubberDuration,
  notes,
}

/// The collections the bulk-edit form can mutate (Add/Remove/Replace).
enum BulkCollectionType { tags, equipment, buddies, tanks, weights, sightings }

/// Already-converted scalar values (metric, enum `.name`/`.code` strings, FK
/// ids) collected from the form controllers, ready to drop into a companion.
class BulkScalarInputs {
  BulkScalarInputs({
    this.diveCenterId,
    this.tripId,
    this.courseId,
    this.diveTypeId,
    this.rating,
    this.isFavorite,
    this.waterType,
    this.visibility,
    this.currentDirection,
    this.currentStrength,
    this.swellHeight,
    this.entryMethod,
    this.exitMethod,
    this.altitude,
    this.surfacePressure,
    this.surfaceIntervalSeconds,
    this.gradientFactorLow,
    this.gradientFactorHigh,
    this.decoAlgorithm,
    this.decoConservatism,
    this.diveComputerModel,
    this.windSpeed,
    this.windDirection,
    this.cloudCover,
    this.precipitation,
    this.humidity,
    this.weatherDescription,
    this.diveMode,
    this.setpointLow,
    this.setpointHigh,
    this.setpointDeco,
    this.diluentO2,
    this.diluentHe,
    this.scrubberType,
    this.scrubberDuration,
    this.notes,
  });

  final String? diveCenterId;
  final String? tripId;
  final String? courseId;
  final String? diveTypeId;
  final int? rating;
  final bool? isFavorite;
  final String? waterType;
  final String? visibility;
  final String? currentDirection;
  final String? currentStrength;
  final double? swellHeight;
  final String? entryMethod;
  final String? exitMethod;
  final double? altitude;
  final double? surfacePressure;
  final int? surfaceIntervalSeconds;
  final int? gradientFactorLow;
  final int? gradientFactorHigh;
  final String? decoAlgorithm;
  final int? decoConservatism;
  final String? diveComputerModel;
  final double? windSpeed;
  final String? windDirection;
  final String? cloudCover;
  final String? precipitation;
  final double? humidity;
  final String? weatherDescription;
  final String? diveMode; // .code
  final double? setpointLow;
  final double? setpointHigh;
  final double? setpointDeco;
  final double? diluentO2;
  final double? diluentHe;
  final String? scrubberType;
  final int? scrubberDuration;
  final String? notes;
}

/// Build the partial scalar companion from the enabled gates. Only enabled
/// fields are present; disabled fields stay absent (so they aren't written).
DivesCompanion buildScalarCompanion(
  Set<BulkField> enabled,
  BulkScalarInputs i,
) {
  var c = const DivesCompanion();
  for (final f in enabled) {
    c = switch (f) {
      BulkField.diveCenter => c.copyWith(diveCenterId: Value(i.diveCenterId)),
      BulkField.trip => c.copyWith(tripId: Value(i.tripId)),
      BulkField.course => c.copyWith(courseId: Value(i.courseId)),
      BulkField.diveType => c.copyWith(
        diveType: Value(i.diveTypeId ?? 'recreational'),
      ),
      BulkField.rating => c.copyWith(rating: Value(i.rating)),
      BulkField.isFavorite => c.copyWith(
        isFavorite: Value(i.isFavorite ?? false),
      ),
      BulkField.waterType => c.copyWith(waterType: Value(i.waterType)),
      BulkField.visibility => c.copyWith(visibility: Value(i.visibility)),
      BulkField.currentDirection => c.copyWith(
        currentDirection: Value(i.currentDirection),
      ),
      BulkField.currentStrength => c.copyWith(
        currentStrength: Value(i.currentStrength),
      ),
      BulkField.swellHeight => c.copyWith(swellHeight: Value(i.swellHeight)),
      BulkField.entryMethod => c.copyWith(entryMethod: Value(i.entryMethod)),
      BulkField.exitMethod => c.copyWith(exitMethod: Value(i.exitMethod)),
      BulkField.altitude => c.copyWith(altitude: Value(i.altitude)),
      BulkField.surfacePressure => c.copyWith(
        surfacePressure: Value(i.surfacePressure),
      ),
      BulkField.surfaceInterval => c.copyWith(
        surfaceIntervalSeconds: Value(i.surfaceIntervalSeconds),
      ),
      BulkField.gradientFactorLow => c.copyWith(
        gradientFactorLow: Value(i.gradientFactorLow),
      ),
      BulkField.gradientFactorHigh => c.copyWith(
        gradientFactorHigh: Value(i.gradientFactorHigh),
      ),
      BulkField.decoAlgorithm => c.copyWith(
        decoAlgorithm: Value(i.decoAlgorithm),
      ),
      BulkField.decoConservatism => c.copyWith(
        decoConservatism: Value(i.decoConservatism),
      ),
      BulkField.diveComputerModel => c.copyWith(
        diveComputerModel: Value(i.diveComputerModel),
      ),
      BulkField.windSpeed => c.copyWith(windSpeed: Value(i.windSpeed)),
      BulkField.windDirection => c.copyWith(
        windDirection: Value(i.windDirection),
      ),
      BulkField.cloudCover => c.copyWith(cloudCover: Value(i.cloudCover)),
      BulkField.precipitation => c.copyWith(
        precipitation: Value(i.precipitation),
      ),
      BulkField.humidity => c.copyWith(humidity: Value(i.humidity)),
      BulkField.weatherDescription => c.copyWith(
        weatherDescription: Value(i.weatherDescription),
      ),
      BulkField.diveMode => c.copyWith(diveMode: Value(i.diveMode ?? 'oc')),
      BulkField.setpointLow => c.copyWith(setpointLow: Value(i.setpointLow)),
      BulkField.setpointHigh => c.copyWith(setpointHigh: Value(i.setpointHigh)),
      BulkField.setpointDeco => c.copyWith(setpointDeco: Value(i.setpointDeco)),
      BulkField.diluentGas => c.copyWith(
        diluentO2: Value(i.diluentO2),
        diluentHe: Value(i.diluentHe),
      ),
      BulkField.scrubberType => c.copyWith(scrubberType: Value(i.scrubberType)),
      BulkField.scrubberDuration => c.copyWith(
        scrubberDurationMinutes: Value(i.scrubberDuration),
      ),
      BulkField.notes => c.copyWith(notes: Value(i.notes ?? '')),
    };
  }
  return c;
}
