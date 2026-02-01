import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Sync data format version for compatibility checking
const int syncFormatVersion = 2;

/// Represents a record deletion to sync across devices.
class SyncDeletion {
  final String id;
  final int deletedAt;

  const SyncDeletion({required this.id, required this.deletedAt});

  Map<String, dynamic> toJson() => {'id': id, 'deletedAt': deletedAt};

  factory SyncDeletion.fromJson(Map<String, dynamic> json) {
    return SyncDeletion(
      id: json['id'] as String,
      deletedAt: json['deletedAt'] as int? ?? 0,
    );
  }
}

/// Represents the complete sync payload
class SyncPayload {
  final int version;
  final int exportedAt;
  final String deviceId;
  final int? lastSyncTimestamp;
  final String checksum;
  final SyncData data;
  final Map<String, List<SyncDeletion>> deletions;

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
    'deletions': deletions.map(
      (key, value) => MapEntry(key, value.map((d) => d.toJson()).toList()),
    ),
  };

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    final rawDeletions =
        (json['deletions'] as Map<String, dynamic>? ?? <String, dynamic>{});
    return SyncPayload(
      version: json['version'] as int,
      exportedAt: json['exportedAt'] as int,
      deviceId: json['deviceId'] as String,
      lastSyncTimestamp: json['lastSyncTimestamp'] as int?,
      checksum: json['checksum'] as String,
      data: SyncData.fromJson(json['data'] as Map<String, dynamic>),
      deletions: rawDeletions.map((key, value) {
        final list = value as List? ?? [];
        final deletions = list
            .map((entry) {
              if (entry is String) {
                return SyncDeletion(id: entry, deletedAt: 0);
              }
              if (entry is Map<String, dynamic>) {
                return SyncDeletion.fromJson(entry);
              }
              if (entry is Map) {
                return SyncDeletion.fromJson(entry.cast<String, dynamic>());
              }
              return null;
            })
            .whereType<SyncDeletion>()
            .toList();
        return MapEntry(key, deletions);
      }),
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
  final List<Map<String, dynamic>> diveEquipment;
  final List<Map<String, dynamic>> diveWeights;
  final List<Map<String, dynamic>> diveSites;
  final List<Map<String, dynamic>> equipment;
  final List<Map<String, dynamic>> equipmentSets;
  final List<Map<String, dynamic>> equipmentSetItems;
  final List<Map<String, dynamic>> media;
  final List<Map<String, dynamic>> buddies;
  final List<Map<String, dynamic>> diveBuddies;
  final List<Map<String, dynamic>> certifications;
  final List<Map<String, dynamic>> serviceRecords;
  final List<Map<String, dynamic>> diveCenters;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> diveTags;
  final List<Map<String, dynamic>> diveTypes;
  final List<Map<String, dynamic>> tankPresets;
  final List<Map<String, dynamic>> diveComputers;
  final List<Map<String, dynamic>> tankPressureProfiles;
  final List<Map<String, dynamic>> tideRecords;
  final List<Map<String, dynamic>> settings;
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
    this.diveEquipment = const [],
    this.diveWeights = const [],
    this.diveSites = const [],
    this.equipment = const [],
    this.equipmentSets = const [],
    this.equipmentSetItems = const [],
    this.media = const [],
    this.buddies = const [],
    this.diveBuddies = const [],
    this.certifications = const [],
    this.serviceRecords = const [],
    this.diveCenters = const [],
    this.trips = const [],
    this.tags = const [],
    this.diveTags = const [],
    this.diveTypes = const [],
    this.tankPresets = const [],
    this.diveComputers = const [],
    this.tankPressureProfiles = const [],
    this.tideRecords = const [],
    this.settings = const [],
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
    'diveEquipment': diveEquipment,
    'diveWeights': diveWeights,
    'diveSites': diveSites,
    'equipment': equipment,
    'equipmentSets': equipmentSets,
    'equipmentSetItems': equipmentSetItems,
    'media': media,
    'buddies': buddies,
    'diveBuddies': diveBuddies,
    'certifications': certifications,
    'serviceRecords': serviceRecords,
    'diveCenters': diveCenters,
    'trips': trips,
    'tags': tags,
    'diveTags': diveTags,
    'diveTypes': diveTypes,
    'tankPresets': tankPresets,
    'diveComputers': diveComputers,
    'tankPressureProfiles': tankPressureProfiles,
    'tideRecords': tideRecords,
    'settings': settings,
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
      diveEquipment: _parseList(json['diveEquipment']),
      diveWeights: _parseList(json['diveWeights']),
      diveSites: _parseList(json['diveSites']),
      equipment: _parseList(json['equipment']),
      equipmentSets: _parseList(json['equipmentSets']),
      equipmentSetItems: _parseList(json['equipmentSetItems']),
      media: _parseList(json['media']),
      buddies: _parseList(json['buddies']),
      diveBuddies: _parseList(json['diveBuddies']),
      certifications: _parseList(json['certifications']),
      serviceRecords: _parseList(json['serviceRecords']),
      diveCenters: _parseList(json['diveCenters']),
      trips: _parseList(json['trips']),
      tags: _parseList(json['tags']),
      diveTags: _parseList(json['diveTags']),
      diveTypes: _parseList(json['diveTypes']),
      tankPresets: _parseList(json['tankPresets']),
      diveComputers: _parseList(json['diveComputers']),
      tankPressureProfiles: _parseList(json['tankPressureProfiles']),
      tideRecords: _parseList(json['tideRecords']),
      settings: _parseList(json['settings']),
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
      buddies.isEmpty &&
      tankPresets.isEmpty &&
      media.isEmpty;
}

/// Service for serializing and deserializing sync data
class SyncDataSerializer {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(SyncDataSerializer);

  Future<List<Map<String, dynamic>>> _safeExport(
    String label,
    Future<List<Map<String, dynamic>>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (e, stackTrace) {
      _log.error('Export failed for $label', e, stackTrace);
      throw Exception('Export failed for $label: $e');
    }
  }

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
        divers: await _safeExport('divers', () => _exportDivers(sinceMs)),
        diverSettings: await _safeExport(
          'diverSettings',
          () => _exportDiverSettings(sinceMs),
        ),
        dives: await _safeExport('dives', () => _exportDives(sinceMs)),
        diveProfiles: await _safeExport(
          'diveProfiles',
          () => _exportDiveProfiles(sinceMs),
        ),
        diveTanks: await _safeExport(
          'diveTanks',
          () => _exportDiveTanks(sinceMs),
        ),
        diveEquipment: await _safeExport(
          'diveEquipment',
          () => _exportDiveEquipment(sinceMs),
        ),
        diveWeights: await _safeExport(
          'diveWeights',
          () => _exportDiveWeights(sinceMs),
        ),
        diveSites: await _safeExport(
          'diveSites',
          () => _exportDiveSites(sinceMs),
        ),
        equipment: await _safeExport(
          'equipment',
          () => _exportEquipment(sinceMs),
        ),
        equipmentSets: await _safeExport(
          'equipmentSets',
          () => _exportEquipmentSets(sinceMs),
        ),
        equipmentSetItems: await _safeExport(
          'equipmentSetItems',
          _exportEquipmentSetItems,
        ),
        media: await _safeExport('media', () => _exportMedia(sinceMs)),
        buddies: await _safeExport('buddies', () => _exportBuddies(sinceMs)),
        diveBuddies: await _safeExport(
          'diveBuddies',
          () => _exportDiveBuddies(sinceMs),
        ),
        certifications: await _safeExport(
          'certifications',
          () => _exportCertifications(sinceMs),
        ),
        serviceRecords: await _safeExport(
          'serviceRecords',
          () => _exportServiceRecords(sinceMs),
        ),
        diveCenters: await _safeExport(
          'diveCenters',
          () => _exportDiveCenters(sinceMs),
        ),
        trips: await _safeExport('trips', () => _exportTrips(sinceMs)),
        tags: await _safeExport('tags', () => _exportTags(sinceMs)),
        diveTags: await _safeExport('diveTags', () => _exportDiveTags(sinceMs)),
        diveTypes: await _safeExport(
          'diveTypes',
          () => _exportDiveTypes(sinceMs),
        ),
        tankPresets: await _safeExport(
          'tankPresets',
          () => _exportTankPresets(sinceMs),
        ),
        diveComputers: await _safeExport(
          'diveComputers',
          () => _exportDiveComputers(sinceMs),
        ),
        tankPressureProfiles: await _safeExport(
          'tankPressureProfiles',
          () => _exportTankPressureProfiles(sinceMs),
        ),
        tideRecords: await _safeExport(
          'tideRecords',
          () => _exportTideRecords(sinceMs),
        ),
        settings: await _safeExport('settings', () => _exportSettings(sinceMs)),
        species: await _safeExport('species', _exportSpecies),
        sightings: await _safeExport('sightings', _exportSightings),
        diveProfileEvents: await _safeExport(
          'diveProfileEvents',
          () => _exportDiveProfileEvents(sinceMs),
        ),
        gasSwitches: await _safeExport(
          'gasSwitches',
          () => _exportGasSwitches(sinceMs),
        ),
      );

      // Group deletions by entity type
      final deletionMap = <String, List<SyncDeletion>>{};
      for (final deletion in deletions) {
        deletionMap
            .putIfAbsent(deletion.entityType, () => [])
            .add(
              SyncDeletion(
                id: deletion.recordId,
                deletedAt: deletion.deletedAt,
              ),
            );
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
  // Import / Apply Methods
  // ============================================================================

  Future<Map<String, dynamic>?> fetchRecord(
    String entityType,
    String recordId,
  ) async {
    switch (entityType) {
      case 'divers':
        final row = await (_db.select(
          _db.divers,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diverToJson(row);
      case 'diverSettings':
        final row = await (_db.select(
          _db.diverSettings,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diverSettingToJson(row);
      case 'dives':
        final row = await (_db.select(
          _db.dives,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveToJson(row);
      case 'diveProfiles':
        final row = await (_db.select(
          _db.diveProfiles,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveProfileToJson(row);
      case 'diveTanks':
        final row = await (_db.select(
          _db.diveTanks,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveTankToJson(row);
      case 'diveEquipment':
        final parts = _splitCompositeId(recordId);
        if (parts.length != 2) return null;
        final row =
            await (_db.select(_db.diveEquipment)
                  ..where((t) => t.diveId.equals(parts[0]))
                  ..where((t) => t.equipmentId.equals(parts[1])))
                .getSingleOrNull();
        return row == null ? null : _diveEquipmentToJson(row);
      case 'diveWeights':
        final row = await (_db.select(
          _db.diveWeights,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveWeightToJson(row);
      case 'diveSites':
        final row = await (_db.select(
          _db.diveSites,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveSiteToJson(row);
      case 'equipment':
        final row = await (_db.select(
          _db.equipment,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _equipmentToJson(row);
      case 'equipmentSets':
        final row = await (_db.select(
          _db.equipmentSets,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _equipmentSetToJson(row);
      case 'equipmentSetItems':
        final parts = _splitCompositeId(recordId);
        if (parts.length != 2) return null;
        final row =
            await (_db.select(_db.equipmentSetItems)
                  ..where((t) => t.setId.equals(parts[0]))
                  ..where((t) => t.equipmentId.equals(parts[1])))
                .getSingleOrNull();
        return row == null
            ? null
            : {'setId': row.setId, 'equipmentId': row.equipmentId};
      case 'media':
        final row = await (_db.select(
          _db.media,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _mediaToJson(row);
      case 'buddies':
        final row = await (_db.select(
          _db.buddies,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _buddyToJson(row);
      case 'diveBuddies':
        final row = await (_db.select(
          _db.diveBuddies,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveBuddyToJson(row);
      case 'certifications':
        final row = await (_db.select(
          _db.certifications,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _certificationToJson(row);
      case 'serviceRecords':
        final row = await (_db.select(
          _db.serviceRecords,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _serviceRecordToJson(row);
      case 'diveCenters':
        final row = await (_db.select(
          _db.diveCenters,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveCenterToJson(row);
      case 'trips':
        final row = await (_db.select(
          _db.trips,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _tripToJson(row);
      case 'tags':
        final row = await (_db.select(
          _db.tags,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _tagToJson(row);
      case 'diveTags':
        final row = await (_db.select(
          _db.diveTags,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveTagToJson(row);
      case 'diveTypes':
        final row = await (_db.select(
          _db.diveTypes,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveTypeToJson(row);
      case 'tankPresets':
        final row = await (_db.select(
          _db.tankPresets,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _tankPresetToJson(row);
      case 'diveComputers':
        final row = await (_db.select(
          _db.diveComputers,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveComputerToJson(row);
      case 'tankPressureProfiles':
        final row = await (_db.select(
          _db.tankPressureProfiles,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _tankPressureProfileToJson(row);
      case 'tideRecords':
        final row = await (_db.select(
          _db.tideRecords,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _tideRecordToJson(row);
      case 'settings':
        final row = await (_db.select(
          _db.settings,
        )..where((t) => t.key.equals(recordId))).getSingleOrNull();
        return row == null ? null : _settingsToJson(row);
      case 'species':
        final row = await (_db.select(
          _db.species,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _speciesToJson(row);
      case 'sightings':
        final row = await (_db.select(
          _db.sightings,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _sightingToJson(row);
      case 'diveProfileEvents':
        final row = await (_db.select(
          _db.diveProfileEvents,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _diveProfileEventToJson(row);
      case 'gasSwitches':
        final row = await (_db.select(
          _db.gasSwitches,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row == null ? null : _gasSwitchToJson(row);
    }
    return null;
  }

  Future<void> upsertRecord(
    String entityType,
    Map<String, dynamic> data,
  ) async {
    switch (entityType) {
      case 'divers':
        await _db.into(_db.divers).insertOnConflictUpdate(Diver.fromJson(data));
        return;
      case 'diverSettings':
        await _db
            .into(_db.diverSettings)
            .insertOnConflictUpdate(
              DiverSetting.fromJson(_applyDiverSettingDefaults(data)),
            );
        return;
      case 'dives':
        await _db.into(_db.dives).insertOnConflictUpdate(Dive.fromJson(data));
        return;
      case 'diveProfiles':
        await _db
            .into(_db.diveProfiles)
            .insertOnConflictUpdate(DiveProfile.fromJson(data));
        return;
      case 'diveTanks':
        await _db
            .into(_db.diveTanks)
            .insertOnConflictUpdate(DiveTank.fromJson(data));
        return;
      case 'diveEquipment':
        await _db
            .into(_db.diveEquipment)
            .insertOnConflictUpdate(DiveEquipmentData.fromJson(data));
        return;
      case 'diveWeights':
        await _db
            .into(_db.diveWeights)
            .insertOnConflictUpdate(DiveWeight.fromJson(data));
        return;
      case 'diveSites':
        await _db
            .into(_db.diveSites)
            .insertOnConflictUpdate(DiveSite.fromJson(data));
        return;
      case 'equipment':
        await _db
            .into(_db.equipment)
            .insertOnConflictUpdate(EquipmentData.fromJson(data));
        return;
      case 'equipmentSets':
        await _db
            .into(_db.equipmentSets)
            .insertOnConflictUpdate(EquipmentSet.fromJson(data));
        return;
      case 'equipmentSetItems':
        await _db
            .into(_db.equipmentSetItems)
            .insertOnConflictUpdate(EquipmentSetItem.fromJson(data));
        return;
      case 'media':
        await _db
            .into(_db.media)
            .insertOnConflictUpdate(MediaData.fromJson(data));
        return;
      case 'buddies':
        await _db
            .into(_db.buddies)
            .insertOnConflictUpdate(Buddy.fromJson(data));
        return;
      case 'diveBuddies':
        await _db
            .into(_db.diveBuddies)
            .insertOnConflictUpdate(DiveBuddy.fromJson(data));
        return;
      case 'certifications':
        await _db
            .into(_db.certifications)
            .insertOnConflictUpdate(Certification.fromJson(data));
        return;
      case 'serviceRecords':
        await _db
            .into(_db.serviceRecords)
            .insertOnConflictUpdate(ServiceRecord.fromJson(data));
        return;
      case 'diveCenters':
        await _db
            .into(_db.diveCenters)
            .insertOnConflictUpdate(DiveCenter.fromJson(data));
        return;
      case 'trips':
        await _db.into(_db.trips).insertOnConflictUpdate(Trip.fromJson(data));
        return;
      case 'tags':
        await _db.into(_db.tags).insertOnConflictUpdate(Tag.fromJson(data));
        return;
      case 'diveTags':
        await _db
            .into(_db.diveTags)
            .insertOnConflictUpdate(DiveTag.fromJson(data));
        return;
      case 'diveTypes':
        await _db
            .into(_db.diveTypes)
            .insertOnConflictUpdate(DiveType.fromJson(data));
        return;
      case 'tankPresets':
        await _db
            .into(_db.tankPresets)
            .insertOnConflictUpdate(TankPreset.fromJson(data));
        return;
      case 'diveComputers':
        await _db
            .into(_db.diveComputers)
            .insertOnConflictUpdate(DiveComputer.fromJson(data));
        return;
      case 'tankPressureProfiles':
        await _db
            .into(_db.tankPressureProfiles)
            .insertOnConflictUpdate(TankPressureProfile.fromJson(data));
        return;
      case 'tideRecords':
        await _db
            .into(_db.tideRecords)
            .insertOnConflictUpdate(TideRecord.fromJson(data));
        return;
      case 'settings':
        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(Setting.fromJson(data));
        return;
      case 'species':
        await _db
            .into(_db.species)
            .insertOnConflictUpdate(Specy.fromJson(data));
        return;
      case 'sightings':
        await _db
            .into(_db.sightings)
            .insertOnConflictUpdate(Sighting.fromJson(data));
        return;
      case 'diveProfileEvents':
        await _db
            .into(_db.diveProfileEvents)
            .insertOnConflictUpdate(DiveProfileEvent.fromJson(data));
        return;
      case 'gasSwitches':
        await _db
            .into(_db.gasSwitches)
            .insertOnConflictUpdate(GasSwitche.fromJson(data));
        return;
    }
  }

  Future<void> deleteRecord(String entityType, String recordId) async {
    switch (entityType) {
      case 'divers':
        await (_db.delete(
          _db.divers,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diverSettings':
        await (_db.delete(
          _db.diverSettings,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'dives':
        await (_db.delete(_db.dives)..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveProfiles':
        await (_db.delete(
          _db.diveProfiles,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveTanks':
        await (_db.delete(
          _db.diveTanks,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveEquipment':
        final parts = _splitCompositeId(recordId);
        if (parts.length == 2) {
          await (_db.delete(_db.diveEquipment)
                ..where((t) => t.diveId.equals(parts[0]))
                ..where((t) => t.equipmentId.equals(parts[1])))
              .go();
        }
        return;
      case 'diveWeights':
        await (_db.delete(
          _db.diveWeights,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveSites':
        await (_db.delete(
          _db.diveSites,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'equipment':
        await (_db.delete(
          _db.equipment,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'equipmentSets':
        await (_db.delete(
          _db.equipmentSets,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'equipmentSetItems':
        final parts = _splitCompositeId(recordId);
        if (parts.length == 2) {
          await (_db.delete(_db.equipmentSetItems)
                ..where((t) => t.setId.equals(parts[0]))
                ..where((t) => t.equipmentId.equals(parts[1])))
              .go();
        }
        return;
      case 'media':
        await (_db.delete(_db.media)..where((t) => t.id.equals(recordId))).go();
        return;
      case 'buddies':
        await (_db.delete(
          _db.buddies,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveBuddies':
        await (_db.delete(
          _db.diveBuddies,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'certifications':
        await (_db.delete(
          _db.certifications,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'serviceRecords':
        await (_db.delete(
          _db.serviceRecords,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveCenters':
        await (_db.delete(
          _db.diveCenters,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'trips':
        await (_db.delete(_db.trips)..where((t) => t.id.equals(recordId))).go();
        return;
      case 'tags':
        await (_db.delete(_db.tags)..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveTags':
        await (_db.delete(
          _db.diveTags,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveTypes':
        await (_db.delete(
          _db.diveTypes,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'tankPresets':
        await (_db.delete(
          _db.tankPresets,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveComputers':
        await (_db.delete(
          _db.diveComputers,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'tankPressureProfiles':
        await (_db.delete(
          _db.tankPressureProfiles,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'tideRecords':
        await (_db.delete(
          _db.tideRecords,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'settings':
        await (_db.delete(
          _db.settings,
        )..where((t) => t.key.equals(recordId))).go();
        return;
      case 'species':
        await (_db.delete(
          _db.species,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'sightings':
        await (_db.delete(
          _db.sightings,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveProfileEvents':
        await (_db.delete(
          _db.diveProfileEvents,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'gasSwitches':
        await (_db.delete(
          _db.gasSwitches,
        )..where((t) => t.id.equals(recordId))).go();
        return;
    }
  }

  List<String> _splitCompositeId(String recordId) {
    return recordId.split('|');
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

  Future<List<Map<String, dynamic>>> _exportDiveEquipment(int? since) async {
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveEquipment,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _diveEquipmentToJson(r)).toList();
    }
    final rows = await _db.select(_db.diveEquipment).get();
    return rows.map((r) => _diveEquipmentToJson(r)).toList();
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

  Future<List<Map<String, dynamic>>> _exportMedia(int? since) async {
    final query = _db.select(_db.media);
    if (since != null) {
      query.where((t) => t.takenAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _mediaToJson(r)).toList();
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

  Future<List<Map<String, dynamic>>> _exportTankPresets(int? since) async {
    final query = _db.select(_db.tankPresets);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _tankPresetToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveComputers(int? since) async {
    final query = _db.select(_db.diveComputers);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _diveComputerToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTankPressureProfiles(
    int? since,
  ) async {
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.tankPressureProfiles,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _tankPressureProfileToJson(r)).toList();
    }
    final rows = await _db.select(_db.tankPressureProfiles).get();
    return rows.map((r) => _tankPressureProfileToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTideRecords(int? since) async {
    if (since != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.tideRecords,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => _tideRecordToJson(r)).toList();
    }
    final rows = await _db.select(_db.tideRecords).get();
    return rows.map((r) => _tideRecordToJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportSettings(int? since) async {
    final query = _db.select(_db.settings);
    if (since != null) {
      query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.map((r) => _settingsToJson(r)).toList();
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
  // Default Value Helpers
  // ============================================================================

  /// Applies default values for DiverSettings fields that may be missing
  /// from older sync data or incomplete conflict records.
  Map<String, dynamic> _applyDiverSettingDefaults(Map<String, dynamic> data) {
    return {
      // Unit settings
      'depthUnit': 'meters',
      'temperatureUnit': 'celsius',
      'pressureUnit': 'bar',
      'volumeUnit': 'liters',
      'weightUnit': 'kilograms',
      'sacUnit': 'litersPerMin',
      // Time/Date format settings
      'timeFormat': 'twelveHour',
      'dateFormat': 'mmmDYYYY',
      // Theme
      'themeMode': 'system',
      // Defaults
      'defaultDiveType': 'recreational',
      'defaultTankVolume': 12.0,
      'defaultStartPressure': 200,
      // Decompression settings
      'gfLow': 30,
      'gfHigh': 70,
      'ppO2MaxWorking': 1.4,
      'ppO2MaxDeco': 1.6,
      'cnsWarningThreshold': 80,
      'ascentRateWarning': 9.0,
      'ascentRateCritical': 12.0,
      'showCeilingOnProfile': true,
      'showAscentRateColors': true,
      'showNdlOnProfile': true,
      'lastStopDepth': 3.0,
      'decoStopIncrement': 3.0,
      // Appearance settings
      'showDepthColoredDiveCards': false,
      'showMapBackgroundOnDiveCards': false,
      'showMapBackgroundOnSiteCards': false,
      // Dive profile markers
      'showMaxDepthMarker': true,
      'showPressureThresholdMarkers': false,
      // Override with actual data (existing values take precedence)
      ...data,
    };
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
    'timeFormat': r.timeFormat,
    'dateFormat': r.dateFormat,
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
    'showDepthColoredDiveCards': r.showDepthColoredDiveCards,
    'showMapBackgroundOnDiveCards': r.showMapBackgroundOnDiveCards,
    'showMapBackgroundOnSiteCards': r.showMapBackgroundOnSiteCards,
    'showMaxDepthMarker': r.showMaxDepthMarker,
    'showPressureThresholdMarkers': r.showPressureThresholdMarkers,
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

  Map<String, dynamic> _diveEquipmentToJson(DiveEquipmentData r) => {
    'id': '${r.diveId}|${r.equipmentId}',
    'diveId': r.diveId,
    'equipmentId': r.equipmentId,
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

  Map<String, dynamic> _mediaToJson(MediaData r) => {
    'id': r.id,
    'diveId': r.diveId,
    'siteId': r.siteId,
    'filePath': r.filePath,
    'fileType': r.fileType,
    'latitude': r.latitude,
    'longitude': r.longitude,
    'takenAt': r.takenAt,
    'caption': r.caption,
    // BLOB field for signatures - base64 encoded for sync
    if (r.imageData != null) 'imageData': base64Encode(r.imageData!),
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
    // BLOB fields - base64 encoded for sync
    if (r.photoFront != null) 'photoFront': base64Encode(r.photoFront!),
    if (r.photoBack != null) 'photoBack': base64Encode(r.photoBack!),
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

  Map<String, dynamic> _tankPresetToJson(TankPreset r) => {
    'id': r.id,
    'diverId': r.diverId,
    'name': r.name,
    'displayName': r.displayName,
    'volumeLiters': r.volumeLiters,
    'workingPressureBar': r.workingPressureBar,
    'material': r.material,
    'description': r.description,
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

  Map<String, dynamic> _tankPressureProfileToJson(TankPressureProfile r) => {
    'id': r.id,
    'diveId': r.diveId,
    'tankId': r.tankId,
    'timestamp': r.timestamp,
    'pressure': r.pressure,
  };

  Map<String, dynamic> _tideRecordToJson(TideRecord r) => {
    'id': r.id,
    'diveId': r.diveId,
    'heightMeters': r.heightMeters,
    'tideState': r.tideState,
    'rateOfChange': r.rateOfChange,
    'highTideHeight': r.highTideHeight,
    'highTideTime': r.highTideTime,
    'lowTideHeight': r.lowTideHeight,
    'lowTideTime': r.lowTideTime,
    'createdAt': r.createdAt,
  };

  Map<String, dynamic> _settingsToJson(Setting r) => {
    'key': r.key,
    'value': r.value,
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
