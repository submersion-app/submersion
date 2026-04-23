import 'dart:typed_data';

/// Per-dive row from the MacDive `ZDIVE` table plus related single-value
/// foreign keys. Lists/junctions are aggregated separately in
/// [MacDiveRawLogbook].
class MacDiveRawDive {
  final int pk;
  final String uuid;
  final String? identifier;

  /// Reference date from `ZRAWDATE` — Core Data stores NSDate as seconds
  /// since 2001-01-01 UTC. The reader converts to a Dart UTC [DateTime].
  final DateTime? rawDate;

  /// NSTimeZone bplist from `ZTIMEZONE`. Decoded by [BPlistDecoder] when
  /// the mapper needs the zone name to reconstruct local time.
  final Uint8List? timezoneBplist;

  /// Max depth in raw MacDive units (depends on `ZMETADATA.SystemOfUnits`).
  final double? maxDepth;
  final double? averageDepth;
  final int? diveNumber;
  final int? repetitiveDiveNumber;
  final double? rating;
  final double? airTemp;
  final double? tempHigh;
  final double? tempLow;
  final double? cns;
  final double? surfaceInterval;
  final double? sampleInterval;
  final double? totalDuration;
  final double? setpointHigh;
  final double? setpointLow;
  final String? decoModel;
  final String? gasModel;
  final String? computer;
  final String? computerSerial;
  final String? notes;
  final String? weather;
  final String? surfaceConditions;
  final String? current;
  final String? entryType;
  final String? diveMaster;
  final String? diveOperator;
  final String? boatName;
  final String? boatCaptain;
  final String? personalMode;
  final String? altitudeMode;
  final String? signature;
  final String? visibility;
  final String? weight;

  /// Foreign key to `ZDIVESITE.Z_PK`.
  final int? diveSiteFk;

  /// Foreign key to `ZCERTIFICATION.Z_PK`.
  final int? certificationFk;

  /// `ZSAMPLES` BLOB — MacDive's proprietary profile-sample format
  /// (NOT bplist; left on the model for future decode work, not
  /// used by M3).
  final Uint8List? samplesBlob;

  /// `ZRAWDATA` BLOB — raw dive-computer sensor dump (format varies by
  /// computer; not bplist).
  final Uint8List? rawDataBlob;

  const MacDiveRawDive({
    required this.pk,
    required this.uuid,
    this.identifier,
    this.rawDate,
    this.timezoneBplist,
    this.maxDepth,
    this.averageDepth,
    this.diveNumber,
    this.repetitiveDiveNumber,
    this.rating,
    this.airTemp,
    this.tempHigh,
    this.tempLow,
    this.cns,
    this.surfaceInterval,
    this.sampleInterval,
    this.totalDuration,
    this.setpointHigh,
    this.setpointLow,
    this.decoModel,
    this.gasModel,
    this.computer,
    this.computerSerial,
    this.notes,
    this.weather,
    this.surfaceConditions,
    this.current,
    this.entryType,
    this.diveMaster,
    this.diveOperator,
    this.boatName,
    this.boatCaptain,
    this.personalMode,
    this.altitudeMode,
    this.signature,
    this.visibility,
    this.weight,
    this.diveSiteFk,
    this.certificationFk,
    this.samplesBlob,
    this.rawDataBlob,
  });
}

class MacDiveRawSite {
  final int pk;
  final String uuid;
  final String? name;
  final String? country;
  final String? location;
  final String? bodyOfWater;
  final String? waterType;
  final String? difficulty;
  final String? flag;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final String? notes;

  const MacDiveRawSite({
    required this.pk,
    required this.uuid,
    this.name,
    this.country,
    this.location,
    this.bodyOfWater,
    this.waterType,
    this.difficulty,
    this.flag,
    this.latitude,
    this.longitude,
    this.altitude,
    this.notes,
  });
}

class MacDiveRawBuddy {
  final int pk;
  final String uuid;
  final String? name;
  const MacDiveRawBuddy({required this.pk, required this.uuid, this.name});
}

class MacDiveRawTag {
  final int pk;
  final String uuid;
  final String? name;
  const MacDiveRawTag({required this.pk, required this.uuid, this.name});
}

class MacDiveRawGear {
  final int pk;
  final String uuid;
  final String? name;
  final String? manufacturer;
  final String? model;
  final String? serial;
  final String? type;
  final double? weight;
  final double? price;
  final DateTime? datePurchase;
  final DateTime? dateNextService;
  final String? notes;
  final String? url;
  final String? warranty;

  const MacDiveRawGear({
    required this.pk,
    required this.uuid,
    this.name,
    this.manufacturer,
    this.model,
    this.serial,
    this.type,
    this.weight,
    this.price,
    this.datePurchase,
    this.dateNextService,
    this.notes,
    this.url,
    this.warranty,
  });
}

class MacDiveRawTank {
  final int pk;
  final String uuid;
  final String? name;
  final double? size;
  final double? workingPressure;
  final String? type;
  const MacDiveRawTank({
    required this.pk,
    required this.uuid,
    this.name,
    this.size,
    this.workingPressure,
    this.type,
  });
}

class MacDiveRawGas {
  final int pk;
  final String uuid;
  final String? name;
  final double? oxygen;
  final double? helium;
  final double? maxPpO2;
  final double? minPpO2;
  const MacDiveRawGas({
    required this.pk,
    required this.uuid,
    this.name,
    this.oxygen,
    this.helium,
    this.maxPpO2,
    this.minPpO2,
  });
}

/// A row from `ZTANKANDGAS` — connects a dive to a specific (tank, gas)
/// pairing with the pressures observed on that dive.
class MacDiveRawTankAndGas {
  final int diveFk;
  final int tankFk;
  final int gasFk;
  final double? airStart;
  final double? airEnd;
  final double? duration;
  final bool isDouble;
  final int order;
  final String? supplyType;
  const MacDiveRawTankAndGas({
    required this.diveFk,
    required this.tankFk,
    required this.gasFk,
    this.airStart,
    this.airEnd,
    this.duration,
    this.isDouble = false,
    this.order = 0,
    this.supplyType,
  });
}

class MacDiveRawCritter {
  final int pk;
  final String uuid;
  final String? name;
  final String? species;
  final double? size;
  final String? notes;
  final String? imagePath;
  const MacDiveRawCritter({
    required this.pk,
    required this.uuid,
    this.name,
    this.species,
    this.size,
    this.notes,
    this.imagePath,
  });
}

class MacDiveRawCertification {
  final int pk;
  final String uuid;
  final String? name;
  final String? agency;
  final DateTime? attained;
  final DateTime? expiry;
  final String? instructorName;
  final String? instructorNumber;
  final String? cardFrontPath;
  final String? cardBackPath;
  const MacDiveRawCertification({
    required this.pk,
    required this.uuid,
    this.name,
    this.agency,
    this.attained,
    this.expiry,
    this.instructorName,
    this.instructorNumber,
    this.cardFrontPath,
    this.cardBackPath,
  });
}

class MacDiveRawServiceRecord {
  final int pk;
  final String uuid;
  final int gearFk;
  final DateTime? serviceDate;
  final String? servicedBy;
  final String? notes;
  const MacDiveRawServiceRecord({
    required this.pk,
    required this.uuid,
    required this.gearFk,
    this.serviceDate,
    this.servicedBy,
    this.notes,
  });
}

class MacDiveRawEvent {
  final int pk;
  final String uuid;
  final int? diveFk;
  final int? type;
  final double? time;
  final String? detail;
  const MacDiveRawEvent({
    required this.pk,
    required this.uuid,
    this.diveFk,
    this.type,
    this.time,
    this.detail,
  });
}

/// A row from MacDive's `ZDIVEIMAGE` table — a photo reference
/// attached to a dive. The BLOB-like fields (image bytes) live on
/// the filesystem at `ZPATH`; this row just carries the reference.
class MacDiveRawDiveImage {
  final int pk;
  final String uuid;
  final int diveFk;
  final int position;
  final String? caption;

  /// MacDive's current path for the photo (`ZPATH`). For externally-sourced
  /// photos this is usually an absolute path on the machine MacDive last
  /// saw it on. For photos imported into MacDive's internal library it is
  /// often just a UUID-based basename (e.g. `1A2B-...-xyz.jpg`), not a
  /// filesystem-absolute path. May or may not exist on the machine running
  /// this import.
  final String? path;

  /// Original absolute path when MacDive first imported this photo
  /// (`ZORIGINALPATH`). Present mainly for externally-sourced photos;
  /// typically null for photos imported into MacDive's internal library.
  final String? originalPath;

  const MacDiveRawDiveImage({
    required this.pk,
    required this.uuid,
    required this.diveFk,
    this.position = 0,
    this.caption,
    this.path,
    this.originalPath,
  });
}

/// Top-level container returned by [MacDiveDbReader.readAll]. Holds all
/// tables keyed for lookup plus the junction tables as dive_pk → list
/// of foreign PKs. The mapper walks this graph to build ImportPayload.
class MacDiveRawLogbook {
  final List<MacDiveRawDive> dives;
  final Map<int, MacDiveRawSite> sitesByPk;
  final Map<int, MacDiveRawBuddy> buddiesByPk;
  final Map<int, MacDiveRawTag> tagsByPk;
  final Map<int, MacDiveRawGear> gearByPk;
  final Map<int, MacDiveRawTank> tanksByPk;
  final Map<int, MacDiveRawGas> gasesByPk;
  final List<MacDiveRawTankAndGas> tankAndGases;
  final Map<int, MacDiveRawCritter> crittersByPk;
  final List<MacDiveRawCertification> certifications;
  final List<MacDiveRawServiceRecord> serviceRecords;
  final List<MacDiveRawEvent> events;
  final List<MacDiveRawDiveImage> diveImages;
  final Map<int, List<int>> diveToBuddyPks;
  final Map<int, List<int>> diveToTagPks;
  final Map<int, List<int>> diveToGearPks;
  final Map<int, List<int>> diveToCritterPks;

  /// Value of `ZMETADATA.ZALL` where `ZIDENTIFIER = 'SystemOfUnits'`.
  /// Used to interpret raw MacDive numerics (Imperial vs Metric).
  final String? unitsPreference;

  const MacDiveRawLogbook({
    required this.dives,
    required this.sitesByPk,
    required this.buddiesByPk,
    required this.tagsByPk,
    required this.gearByPk,
    required this.tanksByPk,
    required this.gasesByPk,
    required this.tankAndGases,
    required this.crittersByPk,
    required this.certifications,
    required this.serviceRecords,
    required this.events,
    this.diveImages = const [],
    required this.diveToBuddyPks,
    required this.diveToTagPks,
    required this.diveToGearPks,
    required this.diveToCritterPks,
    required this.unitsPreference,
  });
}
