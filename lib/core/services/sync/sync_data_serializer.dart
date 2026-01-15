import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Sync data format version for compatibility checking
const int syncFormatVersion = 1;

/// Represents the complete sync payload
class SyncPayload {
  final int version;
  final int exportedAt;
  final String deviceId;
  final int? lastSyncTimestamp;
  final String checksum;
  final SyncData data;
  final Map<String, List<String>> deletions;

  const SyncPayload({
    required this.version,
    required this.exportedAt,
    required this.deviceId,
    this.lastSyncTimestamp,
    required this.checksum,
    required this.data,
    required this.deletions,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'exportedAt': exportedAt,
    'deviceId': deviceId,
    'lastSyncTimestamp': lastSyncTimestamp,
    'checksum': checksum,
    'data': data.toJson(),
    'deletions': deletions,
  };

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    return SyncPayload(
      version: json['version'] as int,
      exportedAt: json['exportedAt'] as int,
      deviceId: json['deviceId'] as String,
      lastSyncTimestamp: json['lastSyncTimestamp'] as int?,
      checksum: json['checksum'] as String,
      data: SyncData.fromJson(json['data'] as Map<String, dynamic>),
      deletions: (json['deletions'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as List).cast<String>()),
      ),
    );
  }
}

/// Container for all syncable data
class SyncData {
  final List<Map<String, dynamic>> divers;
  final List<Map<String, dynamic>> diverSettings;
  final List<Map<String, dynamic>> dives;
  final List<Map<String, dynamic>> diveProfiles;
  final List<Map<String, dynamic>> diveTanks;
  final List<Map<String, dynamic>> diveWeights;
  final List<Map<String, dynamic>> diveSites;
  final List<Map<String, dynamic>> equipment;
  final List<Map<String, dynamic>> equipmentSets;
  final List<Map<String, dynamic>> equipmentSetItems;
  final List<Map<String, dynamic>> buddies;
  final List<Map<String, dynamic>> diveBuddies;
  final List<Map<String, dynamic>> certifications;
  final List<Map<String, dynamic>> serviceRecords;
  final List<Map<String, dynamic>> diveCenters;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> diveTags;
  final List<Map<String, dynamic>> diveTypes;
  final List<Map<String, dynamic>> diveComputers;
  final List<Map<String, dynamic>> species;
  final List<Map<String, dynamic>> sightings;
  final List<Map<String, dynamic>> diveProfileEvents;
  final List<Map<String, dynamic>> gasSwitches;

  const SyncData({
    this.divers = const [],
    this.diverSettings = const [],
    this.dives = const [],
    this.diveProfiles = const [],
    this.diveTanks = const [],
    this.diveWeights = const [],
    this.diveSites = const [],
    this.equipment = const [],
    this.equipmentSets = const [],
    this.equipmentSetItems = const [],
    this.buddies = const [],
    this.diveBuddies = const [],
    this.certifications = const [],
    this.serviceRecords = const [],
    this.diveCenters = const [],
    this.trips = const [],
    this.tags = const [],
    this.diveTags = const [],
    this.diveTypes = const [],
    this.diveComputers = const [],
    this.species = const [],
    this.sightings = const [],
    this.diveProfileEvents = const [],
    this.gasSwitches = const [],
  });

  Map<String, dynamic> toJson() => {
    'divers': divers,
    'diverSettings': diverSettings,
    'dives': dives,
    'diveProfiles': diveProfiles,
    'diveTanks': diveTanks,
    'diveWeights': diveWeights,
    'diveSites': diveSites,
    'equipment': equipment,
    'equipmentSets': equipmentSets,
    'equipmentSetItems': equipmentSetItems,
    'buddies': buddies,
    'diveBuddies': diveBuddies,
    'certifications': certifications,
    'serviceRecords': serviceRecords,
    'diveCenters': diveCenters,
    'trips': trips,
    'tags': tags,
    'diveTags': diveTags,
    'diveTypes': diveTypes,
    'diveComputers': diveComputers,
    'species': species,
    'sightings': sightings,
    'diveProfileEvents': diveProfileEvents,
    'gasSwitches': gasSwitches,
  };

  factory SyncData.fromJson(Map<String, dynamic> json) {
    return SyncData(
      divers: _parseList(json['divers']),
      diverSettings: _parseList(json['diverSettings']),
      dives: _parseList(json['dives']),
      diveProfiles: _parseList(json['diveProfiles']),
      diveTanks: _parseList(json['diveTanks']),
      diveWeights: _parseList(json['diveWeights']),
      diveSites: _parseList(json['diveSites']),
      equipment: _parseList(json['equipment']),
      equipmentSets: _parseList(json['equipmentSets']),
      equipmentSetItems: _parseList(json['equipmentSetItems']),
      buddies: _parseList(json['buddies']),
      diveBuddies: _parseList(json['diveBuddies']),
      certifications: _parseList(json['certifications']),
      serviceRecords: _parseList(json['serviceRecords']),
      diveCenters: _parseList(json['diveCenters']),
      trips: _parseList(json['trips']),
      tags: _parseList(json['tags']),
      diveTags: _parseList(json['diveTags']),
      diveTypes: _parseList(json['diveTypes']),
      diveComputers: _parseList(json['diveComputers']),
      species: _parseList(json['species']),
      sightings: _parseList(json['sightings']),
      diveProfileEvents: _parseList(json['diveProfileEvents']),
      gasSwitches: _parseList(json['gasSwitches']),
    );
  }

  static List<Map<String, dynamic>> _parseList(dynamic value) {
    if (value == null) return [];
    return (value as List).map((e) => e as Map<String, dynamic>).toList();
  }

  /// Check if this sync data is empty
  bool get isEmpty =>
      divers.isEmpty &&
      dives.isEmpty &&
      diveSites.isEmpty &&
      equipment.isEmpty &&
      buddies.isEmpty;
}

/// Service for serializing and deserializing sync data
class SyncDataSerializer {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(SyncDataSerializer);

  /// Export all data modified since the given timestamp
  ///
  /// If [since] is null, exports all data.
  Future<SyncPayload> exportData({
    required String deviceId,
    DateTime? since,
    int? lastSyncTimestamp,
    required List<DeletionLogData> deletions,
  }) async {
    try {
      final sinceMs = since?.millisecondsSinceEpoch;
      _log.info('Exporting data since: ${since ?? 'beginning'}');

      // Export all tables
      final data = SyncData(
        divers: await _exportDivers(sinceMs),
        diverSettings: await _exportDiverSettings(sinceMs),
        dives: await _exportDives(sinceMs),
        diveProfiles: await _exportDiveProfiles(sinceMs),
        diveTanks: await _exportDiveTanks(sinceMs),
        diveWeights: await _exportDiveWeights(sinceMs),
        diveSites: await _exportDiveSites(sinceMs),
        equipment: await _exportEquipment(sinceMs),
        equipmentSets: await _exportEquipmentSets(sinceMs),
        equipmentSetItems: await _exportEquipmentSetItems(),
        buddies: await _exportBuddies(sinceMs),
        diveBuddies: await _exportDiveBuddies(sinceMs),
        certifications: await _exportCertifications(sinceMs),
        serviceRecords: await _exportServiceRecords(sinceMs),
        diveCenters: await _exportDiveCenters(sinceMs),
        trips: await _exportTrips(sinceMs),
        tags: await _exportTags(sinceMs),
        diveTags: await _exportDiveTags(sinceMs),
        diveTypes: await _exportDiveTypes(sinceMs),
        diveComputers: await _exportDiveComputers(sinceMs),
        species: await _exportSpecies(),
        sightings: await _exportSightings(),
        diveProfileEvents: await _exportDiveProfileEvents(sinceMs),
        gasSwitches: await _exportGasSwitches(sinceMs),
      );

      // Group deletions by entity type
      final deletionMap = <String, List<String>>{};
      for (final deletion in deletions) {
        deletionMap
            .putIfAbsent(deletion.entityType, () => [])
            .add(deletion.recordId);
      }

      final exportedAt = DateTime.now().millisecondsSinceEpoch;

      // Compute checksum of data
      final dataJson = jsonEncode(data.toJson());
      final checksum = _computeChecksum(dataJson);

      return SyncPayload(
        version: syncFormatVersion,
        exportedAt: exportedAt,
        deviceId: deviceId,
        lastSyncTimestamp: lastSyncTimestamp,
        checksum: checksum,
        data: data,
        deletions: deletionMap,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to export sync data', e, stackTrace);
      rethrow;
    }
  }

  /// Convert payload to JSON string
  String serializePayload(SyncPayload payload) {
    return jsonEncode(payload.toJson());
  }

  /// Parse JSON string to payload
  SyncPayload deserializePayload(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return SyncPayload.fromJson(map);
  }

  /// Validate checksum of payload
  bool validateChecksum(SyncPayload payload) {
    final dataJson = jsonEncode(payload.data.toJson());
    final computed = _computeChecksum(dataJson);
    return computed == payload.checksum;
  }

  /// Compute SHA-256 checksum
  String _computeChecksum(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ============================================================================
  // Export Methods
  // ============================================================================

  Future<List<Map<String, dynamic>>> _exportDivers(int? since) async {
    final query = _db.select(_db.divers);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _diverToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiverSettings(int? since) async {
    final query = _db.select(_db.diverSettings);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _diverSettingToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDives(int? since) async {
    final query = _db.select(_db.dives);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _diveToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveProfiles(int? since) async {
    // Profile points don't have updatedAt, export all for modified dives
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveProfiles,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _diveProfileToJson(r)).toList();
    }
    final rows = await _db.select(_db.diveProfiles).get();
    return rows.map((r) => _diveProfileToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveTanks(int? since) async {
    // Similar to profiles, export for modified dives
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _diveTankToJson(r)).toList();
    }
    final rows = await _db.select(_db.diveTanks).get();
    return rows.map((r) => _diveTankToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveWeights(int? since) async {
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveWeights,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _diveWeightToJson(r)).toList();
    }
    final rows = await _db.select(_db.diveWeights).get();
    return rows.map((r) => _diveWeightToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveSites(int? since) async {
    final query = _db.select(_db.diveSites);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _diveSiteToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportEquipment(int? since) async {
    final query = _db.select(_db.equipment);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _equipmentToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportEquipmentSets(int? since) async {
    final query = _db.select(_db.equipmentSets);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _equipmentSetToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportEquipmentSetItems() async {
    final rows = await _db.select(_db.equipmentSetItems).get();
    return rows
        .map((r) => {'setId': r.setId, 'equipmentId': r.equipmentId})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _exportBuddies(int? since) async {
    final query = _db.select(_db.buddies);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _buddyToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveBuddies(int? since) async {
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveBuddies,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _diveBuddyToJson(r)).toList();
    }
    final rows = await _db.select(_db.diveBuddies).get();
    return rows.map((r) => _diveBuddyToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportCertifications(int? since) async {
    final query = _db.select(_db.certifications);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _certificationToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportServiceRecords(int? since) async {
    final query = _db.select(_db.serviceRecords);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _serviceRecordToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveCenters(int? since) async {
    final query = _db.select(_db.diveCenters);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _diveCenterToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTrips(int? since) async {
    final query = _db.select(_db.trips);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _tripToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTags(int? since) async {
    final query = _db.select(_db.tags);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _tagToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveTags(int? since) async {
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveTags,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _diveTagToJson(r)).toList();
    }
    final rows = await _db.select(_db.diveTags).get();
    return rows.map((r) => _diveTagToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveTypes(int? since) async {
    final query = _db.select(_db.diveTypes);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _diveTypeToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveComputers(int? since) async {
    final query = _db.select(_db.diveComputers);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _diveComputerToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportSpecies() async {
    final rows = await _db.select(_db.species).get();
    return rows.map((r) => _speciesToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportSightings() async {
    final rows = await _db.select(_db.sightings).get();
    return rows.map((r) => _sightingToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveProfileEvents(
    int? since,
  ) async {
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _diveProfileEventToJson(r)).toList();
    }
    final rows = await _db.select(_db.diveProfileEvents).get();
    return rows.map((r) => _diveProfileEventToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportGasSwitches(int? since) async {
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.gasSwitches,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _gasSwitchToJson(r)).toList();
    }
    final rows = await _db.select(_db.gasSwitches).get();
    return rows.map((r) => _gasSwitchToJson(r)).toList();
  }

  // ============================================================================
  // Row to JSON Converters
  // ============================================================================

  Map<String, dynamic> _diverToJson(Diver r) => {
    'id': r.id,
    'name': r.name,
    'email': r.email,
    'phone': r.phone,
    'photoPath': r.photoPath,
    'emergencyContactName': r.emergencyContactName,
    'emergencyContactPhone': r.emergencyContactPhone,
    'emergencyContactRelation': r.emergencyContactRelation,
    'medicalNotes': r.medicalNotes,
    'bloodType': r.bloodType,
    'allergies': r.allergies,
    'insuranceProvider': r.insuranceProvider,
    'insurancePolicyNumber': r.insurancePolicyNumber,
    'insuranceExpiryDate': r.insuranceExpiryDate,
    'notes': r.notes,
    'isDefault': r.isDefault,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _diverSettingToJson(DiverSetting r) => {
    'id': r.id,
    'diverId': r.diverId,
    'depthUnit': r.depthUnit,
    'temperatureUnit': r.temperatureUnit,
    'pressureUnit': r.pressureUnit,
    'volumeUnit': r.volumeUnit,
    'weightUnit': r.weightUnit,
    'sacUnit': r.sacUnit,
    'themeMode': r.themeMode,
    'defaultDiveType': r.defaultDiveType,
    'defaultTankVolume': r.defaultTankVolume,
    'defaultStartPressure': r.defaultStartPressure,
    'gfLow': r.gfLow,
    'gfHigh': r.gfHigh,
    'ppO2MaxWorking': r.ppO2MaxWorking,
    'ppO2MaxDeco': r.ppO2MaxDeco,
    'cnsWarningThreshold': r.cnsWarningThreshold,
    'ascentRateWarning': r.ascentRateWarning,
    'ascentRateCritical': r.ascentRateCritical,
    'showCeilingOnProfile': r.showCeilingOnProfile,
    'showAscentRateColors': r.showAscentRateColors,
    'showNdlOnProfile': r.showNdlOnProfile,
    'lastStopDepth': r.lastStopDepth,
    'decoStopIncrement': r.decoStopIncrement,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _diveToJson(Dive r) => {
    'id': r.id,
    'diverId': r.diverId,
    'diveNumber': r.diveNumber,
    'diveDateTime': r.diveDateTime,
    'entryTime': r.entryTime,
    'exitTime': r.exitTime,
    'duration': r.duration,
    'runtime': r.runtime,
    'maxDepth': r.maxDepth,
    'avgDepth': r.avgDepth,
    'waterTemp': r.waterTemp,
    'airTemp': r.airTemp,
    'visibility': r.visibility,
    'diveType': r.diveType,
    'buddy': r.buddy,
    'diveMaster': r.diveMaster,
    'notes': r.notes,
    'siteId': r.siteId,
    'rating': r.rating,
    'diveCenterId': r.diveCenterId,
    'tripId': r.tripId,
    'currentDirection': r.currentDirection,
    'currentStrength': r.currentStrength,
    'swellHeight': r.swellHeight,
    'entryMethod': r.entryMethod,
    'exitMethod': r.exitMethod,
    'waterType': r.waterType,
    'altitude': r.altitude,
    'surfacePressure': r.surfacePressure,
    'surfaceIntervalSeconds': r.surfaceIntervalSeconds,
    'gradientFactorLow': r.gradientFactorLow,
    'gradientFactorHigh': r.gradientFactorHigh,
    'diveComputerModel': r.diveComputerModel,
    'diveComputerSerial': r.diveComputerSerial,
    'weightAmount': r.weightAmount,
    'weightType': r.weightType,
    'isFavorite': r.isFavorite,
    'diveMode': r.diveMode,
    'cnsStart': r.cnsStart,
    'cnsEnd': r.cnsEnd,
    'otu': r.otu,
    'computerId': r.computerId,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _diveProfileToJson(DiveProfile r) => {
    'id': r.id,
    'diveId': r.diveId,
    'computerId': r.computerId,
    'isPrimary': r.isPrimary,
    'timestamp': r.timestamp,
    'depth': r.depth,
    'pressure': r.pressure,
    'temperature': r.temperature,
    'heartRate': r.heartRate,
    'ascentRate': r.ascentRate,
    'ceiling': r.ceiling,
    'ndl': r.ndl,
  };

  Map<String, dynamic> _diveTankToJson(DiveTank r) => {
    'id': r.id,
    'diveId': r.diveId,
    'equipmentId': r.equipmentId,
    'volume': r.volume,
    'workingPressure': r.workingPressure,
    'startPressure': r.startPressure,
    'endPressure': r.endPressure,
    'o2Percent': r.o2Percent,
    'hePercent': r.hePercent,
    'tankOrder': r.tankOrder,
    'tankRole': r.tankRole,
    'tankMaterial': r.tankMaterial,
    'tankName': r.tankName,
    'presetName': r.presetName,
  };

  Map<String, dynamic> _diveWeightToJson(DiveWeight r) => {
    'id': r.id,
    'diveId': r.diveId,
    'weightType': r.weightType,
    'amountKg': r.amountKg,
    'notes': r.notes,
    'createdAt': r.createdAt,
  };

  Map<String, dynamic> _diveSiteToJson(DiveSite r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'description': r.description,
    'latitude': r.latitude,
    'longitude': r.longitude,
    'minDepth': r.minDepth,
    'maxDepth': r.maxDepth,
    'difficulty': r.difficulty,
    'country': r.country,
    'region': r.region,
    'rating': r.rating,
    'notes': r.notes,
    'hazards': r.hazards,
    'accessNotes': r.accessNotes,
    'mooringNumber': r.mooringNumber,
    'parkingInfo': r.parkingInfo,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _equipmentToJson(EquipmentData r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'type': r.type,
    'brand': r.brand,
    'model': r.model,
    'serialNumber': r.serialNumber,
    'size': r.size,
    'status': r.status,
    'purchaseDate': r.purchaseDate,
    'purchasePrice': r.purchasePrice,
    'purchaseCurrency': r.purchaseCurrency,
    'lastServiceDate': r.lastServiceDate,
    'serviceIntervalDays': r.serviceIntervalDays,
    'notes': r.notes,
    'isActive': r.isActive,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _equipmentSetToJson(EquipmentSet r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'description': r.description,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _buddyToJson(Buddy r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'email': r.email,
    'phone': r.phone,
    'certificationLevel': r.certificationLevel,
    'certificationAgency': r.certificationAgency,
    'photoPath': r.photoPath,
    'notes': r.notes,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _diveBuddyToJson(DiveBuddy r) => {
    'id': r.id,
    'diveId': r.diveId,
    'buddyId': r.buddyId,
    'role': r.role,
    'createdAt': r.createdAt,
  };

  Map<String, dynamic> _certificationToJson(Certification r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'agency': r.agency,
    'level': r.level,
    'cardNumber': r.cardNumber,
    'issueDate': r.issueDate,
    'expiryDate': r.expiryDate,
    'instructorName': r.instructorName,
    'instructorNumber': r.instructorNumber,
    'photoFrontPath': r.photoFrontPath,
    'photoBackPath': r.photoBackPath,
    'notes': r.notes,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _serviceRecordToJson(ServiceRecord r) => {
    'id': r.id,
    'equipmentId': r.equipmentId,
    'serviceType': r.serviceType,
    'serviceDate': r.serviceDate,
    'provider': r.provider,
    'cost': r.cost,
    'currency': r.currency,
    'nextServiceDue': r.nextServiceDue,
    'notes': r.notes,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _diveCenterToJson(DiveCenter r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'location': r.location,
    'latitude': r.latitude,
    'longitude': r.longitude,
    'country': r.country,
    'phone': r.phone,
    'email': r.email,
    'website': r.website,
    'affiliations': r.affiliations,
    'rating': r.rating,
    'notes': r.notes,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _tripToJson(Trip r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'startDate': r.startDate,
    'endDate': r.endDate,
    'location': r.location,
    'resortName': r.resortName,
    'liveaboardName': r.liveaboardName,
    'notes': r.notes,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _tagToJson(Tag r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'color': r.color,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _diveTagToJson(DiveTag r) => {
    'id': r.id,
    'diveId': r.diveId,
    'tagId': r.tagId,
    'createdAt': r.createdAt,
  };

  Map<String, dynamic> _diveTypeToJson(DiveType r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'isBuiltIn': r.isBuiltIn,
    'sortOrder': r.sortOrder,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _diveComputerToJson(DiveComputer r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'manufacturer': r.manufacturer,
    'model': r.model,
    'serialNumber': r.serialNumber,
    'connectionType': r.connectionType,
    'bluetoothAddress': r.bluetoothAddress,
    'lastDownloadTimestamp': r.lastDownloadTimestamp,
    'diveCount': r.diveCount,
    'isFavorite': r.isFavorite,
    'notes': r.notes,
    'createdAt': r.createdAt,
    'updatedAt': r.updatedAt,
  };

  Map<String, dynamic> _speciesToJson(Specy r) => {
    'id': r.id,
    'commonName': r.commonName,
    'scientificName': r.scientificName,
    'category': r.category,
    'description': r.description,
    'photoPath': r.photoPath,
  };

  Map<String, dynamic> _sightingToJson(Sighting r) => {
    'id': r.id,
    'diveId': r.diveId,
    'speciesId': r.speciesId,
    'count': r.count,
    'notes': r.notes,
  };

  Map<String, dynamic> _diveProfileEventToJson(DiveProfileEvent r) => {
    'id': r.id,
    'diveId': r.diveId,
    'timestamp': r.timestamp,
    'eventType': r.eventType,
    'severity': r.severity,
    'description': r.description,
    'depth': r.depth,
    'value': r.value,
    'tankId': r.tankId,
    'createdAt': r.createdAt,
  };

  Map<String, dynamic> _gasSwitchToJson(GasSwitche r) => {
    'id': r.id,
    'diveId': r.diveId,
    'timestamp': r.timestamp,
    'tankId': r.tankId,
    'depth': r.depth,
    'createdAt': r.createdAt,
  };
}
