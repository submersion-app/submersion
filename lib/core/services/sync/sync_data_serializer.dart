import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Sync data format version for compatibility checking
const int syncFormatVersion = 2;

/// Value serializer used only for sync export/import of BLOB-bearing entities.
///
/// Drift's default serializer encodes a `Uint8List` as a JSON array of byte
/// ints (`[1,2,3,...]`), which is ~3x the size of the raw bytes once rendered
/// as text. Dive-computer fingerprints and embedded photos make that the
/// dominant cost of the sync file. This serializer encodes BLOBs as base64
/// strings instead (~1.33x), delegating every other type to the default.
///
/// `fromJson` accepts BOTH formats so this is a non-breaking change: a payload
/// already in iCloud that used the old array encoding still decodes, while new
/// payloads are written as base64.
class _SyncBlobValueSerializer extends ValueSerializer {
  const _SyncBlobValueSerializer();

  static const _default = ValueSerializer.defaults();

  @override
  T fromJson<T>(dynamic json) {
    // Special-case BLOB columns: accept both base64 strings (the current
    // sync format) and JSON byte arrays (the legacy format). The check is
    // true for both `Uint8List` and `Uint8List?` (since `List<Uint8List>` is
    // a subtype of `List<Uint8List?>`), so a future non-nullable BLOB column
    // would still hit this branch instead of leaking back to the default
    // serializer's array-of-bytes path.
    final typeList = <T>[];
    if (typeList is List<Uint8List?>) {
      if (json == null) return null as T;
      if (json is String) {
        return base64Decode(json) as T;
      }
      if (json is List) {
        return Uint8List.fromList(json.cast<int>()) as T;
      }
    }
    return _default.fromJson<T>(json);
  }

  @override
  dynamic toJson<T>(T value) {
    if (value is Uint8List) {
      return base64Encode(value);
    }
    return _default.toJson<T>(value);
  }
}

const _syncBlobSerializer = _SyncBlobValueSerializer();

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

  /// The `data` section exactly as it appeared in the received document,
  /// re-encoded from the decoded map (Dart maps preserve key order, and the
  /// writer used compact jsonEncode, so this reproduces the writer's bytes).
  /// Checksums must be verified against the WRITER's encoding: re-serializing
  /// through this build's [SyncData.toJson] adds entity keys older builds
  /// never wrote, which made every released build's payload "invalid".
  /// Null for locally constructed payloads (export path).
  final String? rawDataJson;

  /// Random nonce minted for each upload. An install records its own recent
  /// nonces (SharedPreferences); finding a nonce it never minted in its OWN
  /// per-device cloud file means another install is syncing with this
  /// device's identity (a "twin", typically created by whole-container OS
  /// migration). Null in payloads written by older builds.
  final String? uploadNonce;

  /// Library epoch this payload was written under (see library_epoch.dart).
  /// Null on legacy files, which become stale the moment any epoch exists.
  final String? epochId;

  /// Changeset sequence number (null for a base/full payload).
  final int? seq;

  /// The base seq this changeset layers on (optional bookkeeping).
  final int? baseSeq;

  /// HLC watermark this delta starts after (null = full export).
  final String? sinceHlc;

  /// HLC watermark this delta advances to (== publishedHlcHigh after apply).
  final String? toHlc;

  const SyncPayload({
    required this.version,
    required this.exportedAt,
    required this.deviceId,
    this.lastSyncTimestamp,
    required this.checksum,
    required this.data,
    required this.deletions,
    this.rawDataJson,
    this.uploadNonce,
    this.epochId,
    this.seq,
    this.baseSeq,
    this.sinceHlc,
    this.toHlc,
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
    'uploadNonce': uploadNonce,
    'epochId': epochId,
    'seq': seq,
    'baseSeq': baseSeq,
    'sinceHlc': sinceHlc,
    'toHlc': toHlc,
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
      rawDataJson: jsonEncode(json['data']),
      uploadNonce: json['uploadNonce'] as String?,
      epochId: json['epochId'] as String?,
      seq: json['seq'] as int?,
      baseSeq: json['baseSeq'] as int?,
      sinceHlc: json['sinceHlc'] as String?,
      toHlc: json['toHlc'] as String?,
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
  final List<Map<String, dynamic>> courses;
  final List<Map<String, dynamic>> serviceRecords;
  final List<Map<String, dynamic>> diveCenters;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> liveaboardDetails;
  final List<Map<String, dynamic>> itineraryDays;
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
  final List<Map<String, dynamic>> diveCustomFields;
  final List<Map<String, dynamic>> diveDataSources;
  final List<Map<String, dynamic>> siteSpecies;
  final List<Map<String, dynamic>> csvPresets;
  final List<Map<String, dynamic>> viewConfigs;
  final List<Map<String, dynamic>> fieldPresets;

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
    this.courses = const [],
    this.serviceRecords = const [],
    this.diveCenters = const [],
    this.trips = const [],
    this.liveaboardDetails = const [],
    this.itineraryDays = const [],
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
    this.diveCustomFields = const [],
    this.diveDataSources = const [],
    this.siteSpecies = const [],
    this.csvPresets = const [],
    this.viewConfigs = const [],
    this.fieldPresets = const [],
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
    'courses': courses,
    'serviceRecords': serviceRecords,
    'diveCenters': diveCenters,
    'trips': trips,
    'liveaboardDetails': liveaboardDetails,
    'itineraryDays': itineraryDays,
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
    'diveCustomFields': diveCustomFields,
    'diveDataSources': diveDataSources,
    'siteSpecies': siteSpecies,
    'csvPresets': csvPresets,
    'viewConfigs': viewConfigs,
    'fieldPresets': fieldPresets,
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
      courses: _parseList(json['courses']),
      serviceRecords: _parseList(json['serviceRecords']),
      diveCenters: _parseList(json['diveCenters']),
      trips: _parseList(json['trips']),
      liveaboardDetails: _parseList(json['liveaboardDetails']),
      itineraryDays: _parseList(json['itineraryDays']),
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
      diveCustomFields: _parseList(json['diveCustomFields']),
      diveDataSources: _parseList(json['diveDataSources']),
      siteSpecies: _parseList(json['siteSpecies']),
      csvPresets: _parseList(json['csvPresets']),
      viewConfigs: _parseList(json['viewConfigs']),
      fieldPresets: _parseList(json['fieldPresets']),
    );
  }

  static List<Map<String, dynamic>> _parseList(dynamic value) {
    if (value == null) return [];
    return (value as List).map((e) => e as Map<String, dynamic>).toList();
  }
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
      _log.error('Export failed for $label', error: e, stackTrace: stackTrace);
      throw Exception('Export failed for $label: $e');
    }
  }

  /// Full export of the entire library, used by the restore/adopt (Replace
  /// mode) path that re-materializes everything.
  ///
  /// This is NOT the changeset-log base publisher: a changeset-log base is
  /// published via [exportChangeset] with a null `hlcWatermark` -- that yields
  /// the same full snapshot but carries the changeset header fields (seq,
  /// sinceHlc, toHlc) the transport needs. Use [exportChangeset] for an
  /// incremental delta (non-null watermark).
  Future<SyncPayload> exportData({
    required String deviceId,
    int? lastSyncTimestamp,
    required List<DeletionLogData> deletions,
    String? uploadNonce,
    String? epochId,
  }) async {
    try {
      _log.info('Exporting full data snapshot');
      final data = await _buildSyncData(null);
      final dataJson = jsonEncode(data.toJson());
      return SyncPayload(
        version: syncFormatVersion,
        exportedAt: DateTime.now().millisecondsSinceEpoch,
        deviceId: deviceId,
        lastSyncTimestamp: lastSyncTimestamp,
        checksum: _computeChecksum(dataJson),
        data: data,
        deletions: _groupDeletions(deletions),
        uploadNonce: uploadNonce,
        epochId: epochId,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to export sync data',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Incremental delta: only rows changed since [hlcWatermark]. Mutable
  /// entities are filtered by their own hlc; write-once children are gathered
  /// by their HLC parent. Pass null to export everything.
  Future<SyncPayload> exportChangeset({
    required String deviceId,
    required String? hlcWatermark,
    required List<DeletionLogData> deletions,
    int? seq,
    String? uploadNonce,
    String? epochId,
  }) async {
    final data = await _buildSyncData(hlcWatermark);
    // A base (null watermark) carries the FULL deletion log so a cold-start
    // reader can never miss a tombstone. An incremental changeset carries only
    // tombstones newer than the watermark; a null/legacy hlc is always included
    // (safety net), and since it is also in every base this can never drop one.
    // Comparison is String.compareTo on the canonical zero-padded HLC form,
    // matching _maxHlcInData and the row-level isBiggerThanValue data filter.
    final includedDeletions = hlcWatermark == null
        ? deletions
        : deletions
              .where((d) => d.hlc == null || d.hlc!.compareTo(hlcWatermark) > 0)
              .toList();
    final dataJson = jsonEncode(data.toJson());
    return SyncPayload(
      version: syncFormatVersion,
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      checksum: _computeChecksum(dataJson),
      data: data,
      deletions: _groupDeletions(includedDeletions),
      seq: seq,
      sinceHlc: hlcWatermark,
      // Advance past BOTH data rows and included deletions so a deletion-only
      // changeset still lifts publishedHlcHigh -- otherwise the same tombstone
      // would re-publish on every sync. Keep the watermark as a floor so it can
      // never regress.
      toHlc: _maxHlc([
        _maxHlcInData(data),
        ...includedDeletions.map((d) => d.hlc),
        hlcWatermark,
      ]),
      uploadNonce: uploadNonce,
      epochId: epochId,
    );
  }

  /// Group a flat deletion list into the payload's entityType -> deletions map.
  Map<String, List<SyncDeletion>> _groupDeletions(
    List<DeletionLogData> deletions,
  ) {
    final deletionMap = <String, List<SyncDeletion>>{};
    for (final deletion in deletions) {
      deletionMap
          .putIfAbsent(deletion.entityType, () => [])
          .add(
            SyncDeletion(id: deletion.recordId, deletedAt: deletion.deletedAt),
          );
    }
    return deletionMap;
  }

  /// The highest hlc among the HLC-stamped rows in [data] -- the watermark a
  /// changeset advances to. Null when the delta has no HLC-bearing rows.
  String? _maxHlcInData(SyncData data) {
    String? maxHlc;
    for (final list in data.toJson().values) {
      if (list is! List) continue;
      for (final row in list) {
        if (row is Map && row['hlc'] is String) {
          final h = row['hlc'] as String;
          if (maxHlc == null || h.compareTo(maxHlc) > 0) maxHlc = h;
        }
      }
    }
    return maxHlc;
  }

  /// The greatest of several nullable HLC strings (nulls skipped), or null when
  /// all are null. Uses String.compareTo on the canonical zero-padded form,
  /// consistent with [_maxHlcInData] and the row-level hlc filter.
  String? _maxHlc(Iterable<String?> hlcs) {
    String? maxHlc;
    for (final h in hlcs) {
      if (h == null) continue;
      if (maxHlc == null || h.compareTo(maxHlc) > 0) maxHlc = h;
    }
    return maxHlc;
  }

  /// Build the full SyncData, filtering by [hlcSince] (null = full export).
  Future<SyncData> _buildSyncData(String? hlcSince) async {
    return SyncData(
      divers: await _safeExport('divers', () => _exportDivers(hlcSince)),
      diverSettings: await _safeExport(
        'diverSettings',
        () => _exportDiverSettings(hlcSince),
      ),
      dives: await _safeExport('dives', () => _exportDives(hlcSince)),
      diveProfiles: await _safeExport(
        'diveProfiles',
        () => _exportDiveProfiles(hlcSince),
      ),
      diveTanks: await _safeExport(
        'diveTanks',
        () => _exportDiveTanks(hlcSince),
      ),
      diveEquipment: await _safeExport(
        'diveEquipment',
        () => _exportDiveEquipment(hlcSince),
      ),
      diveWeights: await _safeExport(
        'diveWeights',
        () => _exportDiveWeights(hlcSince),
      ),
      diveSites: await _safeExport(
        'diveSites',
        () => _exportDiveSites(hlcSince),
      ),
      equipment: await _safeExport(
        'equipment',
        () => _exportEquipment(hlcSince),
      ),
      equipmentSets: await _safeExport(
        'equipmentSets',
        () => _exportEquipmentSets(hlcSince),
      ),
      equipmentSetItems: await _safeExport(
        'equipmentSetItems',
        () => _exportEquipmentSetItems(hlcSince),
      ),
      media: await _safeExport('media', () => _exportMedia(hlcSince)),
      buddies: await _safeExport('buddies', () => _exportBuddies(hlcSince)),
      diveBuddies: await _safeExport(
        'diveBuddies',
        () => _exportDiveBuddies(hlcSince),
      ),
      certifications: await _safeExport(
        'certifications',
        () => _exportCertifications(hlcSince),
      ),
      courses: await _safeExport('courses', () => _exportCourses(hlcSince)),
      serviceRecords: await _safeExport(
        'serviceRecords',
        () => _exportServiceRecords(hlcSince),
      ),
      diveCenters: await _safeExport(
        'diveCenters',
        () => _exportDiveCenters(hlcSince),
      ),
      trips: await _safeExport('trips', () => _exportTrips(hlcSince)),
      liveaboardDetails: await _safeExport(
        'liveaboardDetails',
        () => _exportLiveaboardDetails(hlcSince),
      ),
      itineraryDays: await _safeExport(
        'itineraryDays',
        () => _exportItineraryDays(hlcSince),
      ),
      tags: await _safeExport('tags', () => _exportTags(hlcSince)),
      diveTags: await _safeExport('diveTags', () => _exportDiveTags(hlcSince)),
      diveTypes: await _safeExport(
        'diveTypes',
        () => _exportDiveTypes(hlcSince),
      ),
      tankPresets: await _safeExport(
        'tankPresets',
        () => _exportTankPresets(hlcSince),
      ),
      diveComputers: await _safeExport(
        'diveComputers',
        () => _exportDiveComputers(hlcSince),
      ),
      tankPressureProfiles: await _safeExport(
        'tankPressureProfiles',
        () => _exportTankPressureProfiles(hlcSince),
      ),
      tideRecords: await _safeExport(
        'tideRecords',
        () => _exportTideRecords(hlcSince),
      ),
      settings: await _safeExport('settings', () => _exportSettings(hlcSince)),
      species: await _safeExport('species', () => _exportSpecies(hlcSince)),
      sightings: await _safeExport(
        'sightings',
        () => _exportSightings(hlcSince),
      ),
      diveProfileEvents: await _safeExport(
        'diveProfileEvents',
        () => _exportDiveProfileEvents(hlcSince),
      ),
      gasSwitches: await _safeExport(
        'gasSwitches',
        () => _exportGasSwitches(hlcSince),
      ),
      diveCustomFields: await _safeExport(
        'diveCustomFields',
        () => _exportDiveCustomFields(hlcSince),
      ),
      diveDataSources: await _safeExport(
        'diveDataSources',
        () => _exportDiveDataSources(hlcSince),
      ),
      siteSpecies: await _safeExport(
        'siteSpecies',
        () => _exportSiteSpecies(hlcSince),
      ),
      csvPresets: await _safeExport(
        'csvPresets',
        () => _exportCsvPresets(hlcSince),
      ),
      viewConfigs: await _safeExport(
        'viewConfigs',
        () => _exportViewConfigs(hlcSince),
      ),
      fieldPresets: await _safeExport(
        'fieldPresets',
        () => _exportFieldPresets(hlcSince),
      ),
    );
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

  /// Validate checksum of payload.
  ///
  /// Verified over the data section as received ([SyncPayload.rawDataJson])
  /// so payloads written by builds with fewer/more entity keys still
  /// validate; falls back to re-serializing for locally built payloads.
  bool validateChecksum(SyncPayload payload) {
    final dataJson = payload.rawDataJson ?? jsonEncode(payload.data.toJson());
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

  /// Runs [body] inside a single DB transaction with deferred FK checks.
  ///
  /// `PRAGMA defer_foreign_keys = ON` is per-transaction in SQLite, so it must
  /// be set as the first statement inside this transaction. It auto-resets at
  /// commit/rollback. Required for `_applyRemotePayload`: a single payload can
  /// contain rows that reference siblings appearing later in the merge order
  /// (e.g. a dive whose `siteId` points at a `diveSites` row applied after).
  Future<T> applyInDeferredFkTransaction<T>(Future<T> Function() body) async {
    return _db.transaction(() async {
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      return await body();
    });
  }

  /// Repairs every foreign key left dangling after a sync apply: a nullable
  /// reference is cleared; a non-nullable orphan is deleted (a manual cascade).
  /// Applying a remote deletion of a parent can leave a local row pointing at
  /// it via a non-cascading FK, which would otherwise fail the deferred-FK
  /// COMMIT and abort the whole sync. Must run inside
  /// [applyInDeferredFkTransaction] so COMMIT sees a consistent graph. Loops
  /// because deleting an orphan can in turn dangle its own children.
  Future<void> repairDanglingForeignKeys() async {
    for (var pass = 0; pass < 5; pass++) {
      final violations = await _db
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (violations.isEmpty) return;

      for (final v in violations) {
        final table = v.read<String>('table');
        final rowid = v.data['rowid'] as int?;
        if (rowid == null) continue; // WITHOUT ROWID tables: not in sync schema
        final fkid = v.read<int>('fkid');

        final fkList = await _db
            .customSelect('PRAGMA foreign_key_list("$table")')
            .get();
        final fk = fkList.where((f) => f.read<int>('id') == fkid).toList();
        if (fk.isEmpty) continue;
        final column = fk.first.read<String>('from');

        final info = await _db
            .customSelect('PRAGMA table_info("$table")')
            .get();
        final col = info
            .where((c) => c.read<String>('name') == column)
            .toList();
        final notNull = col.isNotEmpty && col.first.read<int>('notnull') == 1;

        if (notNull) {
          _log.warning(
            'Sync repair: deleting orphaned $table row (no parent for "$column")',
          );
          await _db.customStatement('DELETE FROM "$table" WHERE rowid = ?', [
            rowid,
          ]);
        } else {
          _log.warning('Sync repair: clearing dangling $table."$column"');
          await _db.customStatement(
            'UPDATE "$table" SET "$column" = NULL WHERE rowid = ?',
            [rowid],
          );
        }
      }
    }
    // Still inconsistent after the cap: fail now with a targeted error rather
    // than letting the deferred-FK COMMIT throw a context-free 787.
    final remaining = await _db.customSelect('PRAGMA foreign_key_check').get();
    _log.error(
      'Foreign-key repair did not converge after 5 passes; '
      '${remaining.length} violation(s) remain',
    );
    throw StateError(
      'Sync foreign-key repair did not converge: '
      '${remaining.length} dangling reference(s) remain after 5 passes',
    );
  }

  Future<Map<String, dynamic>?> fetchRecord(
    String entityType,
    String recordId,
  ) async {
    switch (entityType) {
      case 'divers':
        final row = await (_db.select(
          _db.divers,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diverSettings':
        final row = await (_db.select(
          _db.diverSettings,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'dives':
        final row = await (_db.select(
          _db.dives,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveProfiles':
        final row = await (_db.select(
          _db.diveProfiles,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveTanks':
        final row = await (_db.select(
          _db.diveTanks,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveEquipment':
        final parts = _splitCompositeId(recordId);
        if (parts.length != 2) return null;
        final row =
            await (_db.select(_db.diveEquipment)
                  ..where((t) => t.diveId.equals(parts[0]))
                  ..where((t) => t.equipmentId.equals(parts[1])))
                .getSingleOrNull();
        return row?.toJson();
      case 'diveWeights':
        final row = await (_db.select(
          _db.diveWeights,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveSites':
        final row = await (_db.select(
          _db.diveSites,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'equipment':
        final row = await (_db.select(
          _db.equipment,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'equipmentSets':
        final row = await (_db.select(
          _db.equipmentSets,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
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
        return row?.toJson(serializer: _syncBlobSerializer);
      case 'buddies':
        final row = await (_db.select(
          _db.buddies,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveBuddies':
        final row = await (_db.select(
          _db.diveBuddies,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'certifications':
        final row = await (_db.select(
          _db.certifications,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson(serializer: _syncBlobSerializer);
      case 'courses':
        final row = await (_db.select(
          _db.courses,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        // Drift-generated toJson keeps fetch symmetric with import.
        return row?.toJson();
      case 'serviceRecords':
        final row = await (_db.select(
          _db.serviceRecords,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveCenters':
        final row = await (_db.select(
          _db.diveCenters,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'trips':
        final row = await (_db.select(
          _db.trips,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'liveaboardDetails':
        final row = await (_db.select(
          _db.liveaboardDetailRecords,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'itineraryDays':
        final row = await (_db.select(
          _db.tripItineraryDays,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'tags':
        final row = await (_db.select(
          _db.tags,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveTags':
        final row = await (_db.select(
          _db.diveTags,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveTypes':
        final row = await (_db.select(
          _db.diveTypes,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'tankPresets':
        final row = await (_db.select(
          _db.tankPresets,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveComputers':
        final row = await (_db.select(
          _db.diveComputers,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'tankPressureProfiles':
        final row = await (_db.select(
          _db.tankPressureProfiles,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'tideRecords':
        final row = await (_db.select(
          _db.tideRecords,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'settings':
        final row = await (_db.select(
          _db.settings,
        )..where((t) => t.key.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'species':
        final row = await (_db.select(
          _db.species,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'sightings':
        final row = await (_db.select(
          _db.sightings,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveProfileEvents':
        final row = await (_db.select(
          _db.diveProfileEvents,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'gasSwitches':
        final row = await (_db.select(
          _db.gasSwitches,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveCustomFields':
        final row = await (_db.select(
          _db.diveCustomFields,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'diveDataSources':
        final row = await (_db.select(
          _db.diveDataSources,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson(serializer: _syncBlobSerializer);
      case 'siteSpecies':
        final row = await (_db.select(
          _db.siteSpecies,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'csvPresets':
        final row = await (_db.select(
          _db.csvPresets,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'viewConfigs':
        final row = await (_db.select(
          _db.viewConfigs,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'fieldPresets':
        final row = await (_db.select(
          _db.fieldPresets,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
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
            .insertOnConflictUpdate(
              MediaData.fromJson(data, serializer: _syncBlobSerializer),
            );
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
            .insertOnConflictUpdate(
              Certification.fromJson(data, serializer: _syncBlobSerializer),
            );
        return;
      case 'courses':
        await _db
            .into(_db.courses)
            .insertOnConflictUpdate(Course.fromJson(data));
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
      case 'liveaboardDetails':
        await _db
            .into(_db.liveaboardDetailRecords)
            .insertOnConflictUpdate(LiveaboardDetailRecord.fromJson(data));
        return;
      case 'itineraryDays':
        await _db
            .into(_db.tripItineraryDays)
            .insertOnConflictUpdate(TripItineraryDay.fromJson(data));
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
        // Never let an incoming payload overwrite a device-local settings key
        // (e.g. active_diver_id). Export filters these, but a peer on an older
        // build may still ship them; applying would switch this device's
        // active diver. Symmetric with _exportSettings.
        if (_deviceLocalSettingsKeys.contains(data['key'])) {
          return;
        }
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
        // Back-compat: payloads from pre-v68 peers lack `source`. Default to
        // 'imported' to match the v67→v68 migration's DEFAULT for existing rows.
        final diveProfileEventData = data['source'] == null
            ? {...data, 'source': 'imported'}
            : data;
        await _db
            .into(_db.diveProfileEvents)
            .insertOnConflictUpdate(
              DiveProfileEvent.fromJson(diveProfileEventData),
            );
        return;
      case 'gasSwitches':
        await _db
            .into(_db.gasSwitches)
            .insertOnConflictUpdate(GasSwitche.fromJson(data));
        return;
      case 'diveCustomFields':
        await _db
            .into(_db.diveCustomFields)
            .insertOnConflictUpdate(
              DiveCustomField.fromJson(_withTimestampDefaults(data)),
            );
        return;
      case 'diveDataSources':
        await _db
            .into(_db.diveDataSources)
            .insertOnConflictUpdate(
              DiveDataSourcesData.fromJson(
                _withTimestampDefaults(data),
                serializer: _syncBlobSerializer,
              ),
            );
        return;
      case 'siteSpecies':
        await _db
            .into(_db.siteSpecies)
            .insertOnConflictUpdate(
              SiteSpecy.fromJson(_withTimestampDefaults(data)),
            );
        return;
      case 'csvPresets':
        await _db
            .into(_db.csvPresets)
            .insertOnConflictUpdate(
              CsvPreset.fromJson(_withTimestampDefaults(data)),
            );
        return;
      case 'viewConfigs':
        await _db
            .into(_db.viewConfigs)
            .insertOnConflictUpdate(
              ViewConfig.fromJson(_withTimestampDefaults(data)),
            );
        return;
      case 'fieldPresets':
        await _db
            .into(_db.fieldPresets)
            .insertOnConflictUpdate(
              FieldPreset.fromJson(_withTimestampDefaults(data)),
            );
        return;
    }
  }

  /// Every local row id for [entityType], in the id form [deleteRecord]
  /// accepts: plain `id` for most entities, `key` for `settings`, and the
  /// composite `a|b` form (matching [_compositeId]) for the two junction
  /// tables. Id-only projection: it never materializes full rows, so it stays
  /// bounded even for row-per-sample tables (diveProfiles, tankPressureProfiles)
  /// with millions of rows. Used by the streaming replace-adopt to delete local
  /// rows absent from the restored library (#358). Unknown entity types yield
  /// an empty set. Mirrors the entity -> table mapping in [upsertRecord] /
  /// [deleteRecord]; a missing case silently returns empty, so the
  /// "every synced entity" smoke test guards against that.
  Future<Set<String>> recordIdsFor(String entityType) async {
    Future<Set<String>> plain(
      ResultSetImplementation<HasResultSet, dynamic> table,
      GeneratedColumn<String> idColumn,
    ) async {
      final query = _db.selectOnly(table)..addColumns([idColumn]);
      return {for (final row in await query.get()) row.read(idColumn)!};
    }

    switch (entityType) {
      case 'settings':
        return plain(_db.settings, _db.settings.key);
      case 'diveEquipment':
        final query = _db.selectOnly(_db.diveEquipment)
          ..addColumns([
            _db.diveEquipment.diveId,
            _db.diveEquipment.equipmentId,
          ]);
        return {
          for (final row in await query.get())
            '${row.read(_db.diveEquipment.diveId)}|'
                '${row.read(_db.diveEquipment.equipmentId)}',
        };
      case 'equipmentSetItems':
        final query = _db.selectOnly(_db.equipmentSetItems)
          ..addColumns([
            _db.equipmentSetItems.setId,
            _db.equipmentSetItems.equipmentId,
          ]);
        return {
          for (final row in await query.get())
            '${row.read(_db.equipmentSetItems.setId)}|'
                '${row.read(_db.equipmentSetItems.equipmentId)}',
        };
      case 'divers':
        return plain(_db.divers, _db.divers.id);
      case 'diverSettings':
        return plain(_db.diverSettings, _db.diverSettings.id);
      case 'buddies':
        return plain(_db.buddies, _db.buddies.id);
      case 'diveCenters':
        return plain(_db.diveCenters, _db.diveCenters.id);
      case 'trips':
        return plain(_db.trips, _db.trips.id);
      case 'liveaboardDetails':
        return plain(
          _db.liveaboardDetailRecords,
          _db.liveaboardDetailRecords.id,
        );
      case 'itineraryDays':
        return plain(_db.tripItineraryDays, _db.tripItineraryDays.id);
      case 'equipment':
        return plain(_db.equipment, _db.equipment.id);
      case 'equipmentSets':
        return plain(_db.equipmentSets, _db.equipmentSets.id);
      case 'diveTypes':
        return plain(_db.diveTypes, _db.diveTypes.id);
      case 'tankPresets':
        return plain(_db.tankPresets, _db.tankPresets.id);
      case 'diveComputers':
        return plain(_db.diveComputers, _db.diveComputers.id);
      case 'species':
        return plain(_db.species, _db.species.id);
      case 'tags':
        return plain(_db.tags, _db.tags.id);
      case 'courses':
        return plain(_db.courses, _db.courses.id);
      case 'dives':
        return plain(_db.dives, _db.dives.id);
      case 'diveSites':
        return plain(_db.diveSites, _db.diveSites.id);
      case 'diveTanks':
        return plain(_db.diveTanks, _db.diveTanks.id);
      case 'diveWeights':
        return plain(_db.diveWeights, _db.diveWeights.id);
      case 'diveTags':
        return plain(_db.diveTags, _db.diveTags.id);
      case 'diveBuddies':
        return plain(_db.diveBuddies, _db.diveBuddies.id);
      case 'diveProfiles':
        return plain(_db.diveProfiles, _db.diveProfiles.id);
      case 'diveProfileEvents':
        return plain(_db.diveProfileEvents, _db.diveProfileEvents.id);
      case 'gasSwitches':
        return plain(_db.gasSwitches, _db.gasSwitches.id);
      case 'diveCustomFields':
        return plain(_db.diveCustomFields, _db.diveCustomFields.id);
      case 'diveDataSources':
        return plain(_db.diveDataSources, _db.diveDataSources.id);
      case 'siteSpecies':
        return plain(_db.siteSpecies, _db.siteSpecies.id);
      case 'csvPresets':
        return plain(_db.csvPresets, _db.csvPresets.id);
      case 'viewConfigs':
        return plain(_db.viewConfigs, _db.viewConfigs.id);
      case 'fieldPresets':
        return plain(_db.fieldPresets, _db.fieldPresets.id);
      case 'tankPressureProfiles':
        return plain(_db.tankPressureProfiles, _db.tankPressureProfiles.id);
      case 'tideRecords':
        return plain(_db.tideRecords, _db.tideRecords.id);
      case 'sightings':
        return plain(_db.sightings, _db.sightings.id);
      case 'certifications':
        return plain(_db.certifications, _db.certifications.id);
      case 'serviceRecords':
        return plain(_db.serviceRecords, _db.serviceRecords.id);
      default:
        return <String>{};
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
      case 'courses':
        await (_db.delete(
          _db.courses,
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
      case 'liveaboardDetails':
        await (_db.delete(
          _db.liveaboardDetailRecords,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'itineraryDays':
        await (_db.delete(
          _db.tripItineraryDays,
        )..where((t) => t.id.equals(recordId))).go();
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
      case 'diveCustomFields':
        await (_db.delete(
          _db.diveCustomFields,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'diveDataSources':
        await (_db.delete(
          _db.diveDataSources,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'siteSpecies':
        await (_db.delete(
          _db.siteSpecies,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'csvPresets':
        await (_db.delete(
          _db.csvPresets,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'viewConfigs':
        await (_db.delete(
          _db.viewConfigs,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'fieldPresets':
        await (_db.delete(
          _db.fieldPresets,
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

  Future<List<Map<String, dynamic>>> _exportDivers(String? hlcSince) async {
    final query = _db.select(_db.divers);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiverSettings(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.diverSettings);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDives(String? hlcSince) async {
    final query = _db.select(_db.dives);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    // Export via the generated data-class toJson() so the keys are symmetric
    // with Dive.fromJson used on import. A hand-maintained map silently drops
    // fields (e.g. bottomTime, GPS) and breaks cross-device sync.
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveProfiles(
    String? hlcSince,
  ) async {
    // Profile points don't have updatedAt, export all for modified dives
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveProfiles,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveProfiles).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveTanks(String? hlcSince) async {
    // Similar to profiles, export for modified dives
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveTanks).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveEquipment(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveEquipment,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveEquipment).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveWeights(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveWeights,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveWeights).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveSites(String? hlcSince) async {
    final query = _db.select(_db.diveSites);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportEquipment(String? hlcSince) async {
    final query = _db.select(_db.equipment);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportEquipmentSets(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.equipmentSets);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportEquipmentSetItems(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final changedSets = await (_db.select(
        _db.equipmentSets,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final setIds = changedSets.map((s) => s.id).toSet();
      if (setIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.equipmentSetItems,
      )..where((t) => t.setId.isIn(setIds))).get();
      return rows
          .map((r) => {'setId': r.setId, 'equipmentId': r.equipmentId})
          .toList();
    }
    final rows = await _db.select(_db.equipmentSetItems).get();
    return rows
        .map((r) => {'setId': r.setId, 'equipmentId': r.equipmentId})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _exportMedia(String? hlcSince) async {
    final query = _db.select(_db.media);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    // Media carries the imageData BLOB; encode it as base64, not a byte array.
    return rows.map((r) => r.toJson(serializer: _syncBlobSerializer)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportBuddies(String? hlcSince) async {
    final query = _db.select(_db.buddies);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveBuddies(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveBuddies,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveBuddies).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportCertifications(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.certifications);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    // Certifications carry photoFront/photoBack BLOBs; base64-encode them.
    return rows.map((r) => r.toJson(serializer: _syncBlobSerializer)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportCourses(String? hlcSince) async {
    final query = _db.select(_db.courses);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportServiceRecords(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.serviceRecords);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveCenters(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.diveCenters);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTrips(String? hlcSince) async {
    final query = _db.select(_db.trips);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportLiveaboardDetails(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.liveaboardDetailRecords);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportItineraryDays(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.tripItineraryDays);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTags(String? hlcSince) async {
    final query = _db.select(_db.tags);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveTags(String? hlcSince) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveTags,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveTags).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveTypes(String? hlcSince) async {
    // Built-in dive types are re-seeded identically on every device at first
    // launch and cannot be edited, so syncing them only risks cross-device
    // ID collisions and payload bloat. Export custom types only.
    final query = _db.select(_db.diveTypes)
      ..where((t) => t.isBuiltIn.equals(false));
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTankPresets(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.tankPresets);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveComputers(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.diveComputers);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTankPressureProfiles(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.tankPressureProfiles,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.tankPressureProfiles).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTideRecords(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.tideRecords,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.tideRecords).get();
    return rows.map((r) => r.toJson()).toList();
  }

  /// Settings keys that hold per-device state and must never sync.
  ///
  /// Including these in the payload causes the receiving device to flag a
  /// conflict on every cross-device pull (same `key` row, different value
  /// per device).
  ///
  /// Audit (last reviewed when [SyncData] grew to ~39 entities): only three
  /// keys are ever written to the `settings` table in app code:
  ///   - `active_diver_id` (per-device — each device auto-creates its own
  ///     owner diver at first launch). FILTERED.
  ///   - `share_new_records_by_default` (global user preference). Syncs.
  ///   - `nav_primary_ids` (user's preferred top-level nav). Syncs.
  /// New keys should be assessed against the rule: "is this answer the same
  /// across all of one user's devices?" If no, add it here.
  static const Set<String> _deviceLocalSettingsKeys = {'active_diver_id'};

  Future<List<Map<String, dynamic>>> _exportSettings(String? hlcSince) async {
    final query = _db.select(_db.settings);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows
        .where((r) => !_deviceLocalSettingsKeys.contains(r.key))
        .map((r) => r.toJson())
        .toList();
  }

  Future<List<Map<String, dynamic>>> _exportSpecies(String? hlcSince) async {
    // Built-in species come from a bundled asset re-seeded on every device;
    // only export user-created species. (Built-ins use stable bundled IDs so
    // they would not collide, but there is no value in shipping them.)
    final query = _db.select(_db.species)
      ..where((t) => t.isBuiltIn.equals(false));
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportSightings(String? hlcSince) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.sightings,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.sightings).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveCustomFields(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveCustomFields,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveCustomFields).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveDataSources(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveDataSources,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      // Carries rawData/rawFingerprint BLOBs; base64-encode them.
      return rows
          .map((r) => r.toJson(serializer: _syncBlobSerializer))
          .toList();
    }
    final rows = await _db.select(_db.diveDataSources).get();
    // Carries rawData/rawFingerprint BLOBs; base64-encode them.
    return rows.map((r) => r.toJson(serializer: _syncBlobSerializer)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportSiteSpecies(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedSites = await (_db.select(
        _db.diveSites,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final siteIds = modifiedSites.map((s) => s.id).toSet();
      if (siteIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.siteSpecies,
      )..where((t) => t.siteId.isIn(siteIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.siteSpecies).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportCsvPresets(String? hlcSince) async {
    final query = _db.select(_db.csvPresets);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportViewConfigs(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.viewConfigs);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportFieldPresets(
    String? hlcSince,
  ) async {
    // Built-in field presets are re-seeded per diver on every device; export
    // only user-created presets.
    final query = _db.select(_db.fieldPresets)
      ..where((t) => t.isBuiltIn.equals(false));
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDiveProfileEvents(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveProfileEvents).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportGasSwitches(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.gasSwitches,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.gasSwitches).get();
    return rows.map((r) => r.toJson()).toList();
  }

  // ============================================================================
  // Default Value Helpers
  // ============================================================================

  /// Applies default values for DiverSettings fields that may be missing
  /// from older sync data or incomplete conflict records.
  /// Defensive back-compat for the entities most recently added to SyncData:
  /// if a peer ever ships a partial record missing `createdAt`/`updatedAt`,
  /// fall back to "now" rather than letting Drift's strict `fromJson` throw
  /// when it sees `null` where `int` was expected. The new entities all use
  /// Unix-milliseconds for their timestamp columns.
  Map<String, dynamic> _withTimestampDefaults(Map<String, dynamic> data) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {'createdAt': now, 'updatedAt': now, 'importedAt': now, ...data};
  }

  Map<String, dynamic> _applyDiverSettingDefaults(Map<String, dynamic> data) {
    final merged = {
      // Unit settings
      'depthUnit': 'meters',
      'temperatureUnit': 'celsius',
      'pressureUnit': 'bar',
      'volumeUnit': 'liters',
      'weightUnit': 'kilograms',
      'altitudeUnit': 'meters',
      'sacUnit': 'litersPerMin',
      // Time/Date format settings
      'timeFormat': 'twelveHour',
      'dateFormat': 'mmmDYYYY',
      // Theme
      'themeMode': 'system',
      'themePreset': 'submersion',
      // Defaults
      'defaultDiveType': 'recreational',
      'defaultTankVolume': 12.0,
      'defaultStartPressure': 200,
      'defaultTankPreset': 'al80',
      'applyDefaultTankToImports': false,
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
      'cardColorAttribute': 'none',
      'cardColorGradientPreset': 'ocean',
      'cardColorGradientStart': null,
      'cardColorGradientEnd': null,
      'showMapBackgroundOnDiveCards': false,
      'showMapBackgroundOnSiteCards': false,
      // Dive profile markers
      'showMaxDepthMarker': true,
      'showPressureThresholdMarkers': false,
      // Override with actual data (existing values take precedence)
      ...data,
    };
    // Backward compat: old exports have showDepthColoredDiveCards but not
    // cardColorAttribute. If the old boolean is true and no new key was
    // provided, infer depth coloring.
    if (merged['cardColorAttribute'] == 'none' &&
        data['showDepthColoredDiveCards'] == true &&
        !data.containsKey('cardColorAttribute')) {
      merged['cardColorAttribute'] = 'depth';
    }
    return merged;
  }
}
