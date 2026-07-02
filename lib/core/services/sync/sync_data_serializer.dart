import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Sync data format version for compatibility checking
const int syncFormatVersion = 2;

/// Unique-ish suffix for base temp files (deviceId + seq already scope them).
const _baseTempUuid = Uuid();

/// Result of streaming a base snapshot to a temp file. The caller owns [path]
/// and must delete it. [byteLength] is the on-disk base size (== manifest
/// `baseBytes`); [rowCount] is the total rows written (0 => an empty library).
typedef StreamedBase = ({
  String path,
  int byteLength,
  int exportedAt,
  String? toHlc,
  int rowCount,
});

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
  final List<Map<String, dynamic>> diveDiveTypes;
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
    this.diveDiveTypes = const [],
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
    'diveDiveTypes': diveDiveTypes,
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
      diveDiveTypes: _parseList(json['diveDiveTypes']),
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

  /// Ordered table descriptors for a base snapshot, matching SyncData.toJson.
  /// `table != null` => keyset-page by `id`; otherwise `full` loads the whole
  /// (small, composite-key) table once. `blob` selects the base64 BLOB
  /// serializer (media / certifications / diveDataSources).
  List<
    ({
      String key,
      TableInfo<Table, dynamic>? table,
      bool blob,
      Future<List<Map<String, dynamic>>> Function()? full,
    })
  >
  get _baseTables => [
    (key: 'divers', table: _db.divers, blob: false, full: null),
    (key: 'diverSettings', table: _db.diverSettings, blob: false, full: null),
    (key: 'dives', table: _db.dives, blob: false, full: null),
    (key: 'diveProfiles', table: _db.diveProfiles, blob: false, full: null),
    (key: 'diveTanks', table: _db.diveTanks, blob: false, full: null),
    (
      key: 'diveEquipment',
      table: null,
      blob: false,
      full: () => _exportDiveEquipment(null),
    ),
    (key: 'diveWeights', table: _db.diveWeights, blob: false, full: null),
    (key: 'diveSites', table: _db.diveSites, blob: false, full: null),
    (key: 'equipment', table: _db.equipment, blob: false, full: null),
    (key: 'equipmentSets', table: _db.equipmentSets, blob: false, full: null),
    (
      key: 'equipmentSetItems',
      table: null,
      blob: false,
      full: () => _exportEquipmentSetItems(null),
    ),
    (key: 'media', table: _db.media, blob: true, full: null),
    (key: 'buddies', table: _db.buddies, blob: false, full: null),
    (key: 'diveBuddies', table: _db.diveBuddies, blob: false, full: null),
    (key: 'certifications', table: _db.certifications, blob: true, full: null),
    (key: 'courses', table: _db.courses, blob: false, full: null),
    (key: 'serviceRecords', table: _db.serviceRecords, blob: false, full: null),
    (key: 'diveCenters', table: _db.diveCenters, blob: false, full: null),
    (key: 'trips', table: _db.trips, blob: false, full: null),
    (
      key: 'liveaboardDetails',
      table: _db.liveaboardDetailRecords,
      blob: false,
      full: null,
    ),
    (
      key: 'itineraryDays',
      table: _db.tripItineraryDays,
      blob: false,
      full: null,
    ),
    (key: 'tags', table: _db.tags, blob: false, full: null),
    (key: 'diveTags', table: _db.diveTags, blob: false, full: null),
    (key: 'diveDiveTypes', table: _db.diveDiveTypes, blob: false, full: null),
    // diveTypes/species/fieldPresets exclude built-in reference data
    // (isBuiltIn=false), so reuse their exporters rather than paging all rows.
    (
      key: 'diveTypes',
      table: null,
      blob: false,
      full: () => _exportDiveTypes(null),
    ),
    (key: 'tankPresets', table: _db.tankPresets, blob: false, full: null),
    (key: 'diveComputers', table: _db.diveComputers, blob: false, full: null),
    (
      key: 'tankPressureProfiles',
      table: _db.tankPressureProfiles,
      blob: false,
      full: null,
    ),
    (key: 'tideRecords', table: _db.tideRecords, blob: false, full: null),
    (
      key: 'settings',
      table: null,
      blob: false,
      full: () => _exportSettings(null),
    ),
    (
      key: 'species',
      table: null,
      blob: false,
      full: () => _exportSpecies(null),
    ),
    (key: 'sightings', table: _db.sightings, blob: false, full: null),
    (
      key: 'diveProfileEvents',
      table: _db.diveProfileEvents,
      blob: false,
      full: null,
    ),
    (key: 'gasSwitches', table: _db.gasSwitches, blob: false, full: null),
    (
      key: 'diveCustomFields',
      table: _db.diveCustomFields,
      blob: false,
      full: null,
    ),
    (
      key: 'diveDataSources',
      table: _db.diveDataSources,
      blob: true,
      full: null,
    ),
    (key: 'siteSpecies', table: _db.siteSpecies, blob: false, full: null),
    (key: 'csvPresets', table: _db.csvPresets, blob: false, full: null),
    (key: 'viewConfigs', table: _db.viewConfigs, blob: false, full: null),
    (
      key: 'fieldPresets',
      table: null,
      blob: false,
      full: () => _exportFieldPresets(null),
    ),
  ];

  /// Test seam: the base table order, asserted equal to SyncData.toJson keys so
  /// a dropped/added/misordered entity is caught at build time.
  static List<String> get debugBaseTableKeys =>
      SyncDataSerializer()._baseTables.map((t) => t.key).toList();

  /// One keyset page (`id > cursor`, ascending, up to [limit]) of an id-PK
  /// table, as JSON rows identical to the table's own `toJson` (BLOB serializer
  /// applied for BLOB tables). O(n) total across pages; never loads the whole
  /// table into memory.
  Future<List<Map<String, dynamic>>> _pageBaseTableById(
    TableInfo<Table, dynamic> table, {
    required String? cursor,
    required int limit,
    required bool blob,
  }) async {
    final name = table.actualTableName;
    final rows = cursor == null
        ? await _db
              .customSelect(
                'SELECT * FROM "$name" ORDER BY id LIMIT ?',
                variables: [Variable.withInt(limit)],
              )
              .get()
        : await _db
              .customSelect(
                'SELECT * FROM "$name" WHERE id > ? ORDER BY id LIMIT ?',
                variables: [
                  Variable.withString(cursor),
                  Variable.withInt(limit),
                ],
              )
              .get();
    return rows.map((r) {
      final data = table.map(r.data) as dynamic;
      return (blob
              ? data.toJson(serializer: _syncBlobSerializer)
              : data.toJson())
          as Map<String, dynamic>;
    }).toList();
  }

  /// Streams a full base snapshot to a temp file as exactly
  /// `jsonEncode(SyncPayload.toJson())`, in bounded memory (one keyset page +
  /// one write). Replaces `exportChangeset(null)` + `encodeChangeset` on the
  /// publish/compact path, whose full-graph materialization OOM-crashed iOS on
  /// large libraries (#358, write side). Rows stream in `id` order; the internal
  /// `checksum` is patched in over the streamed `data` bytes via a single
  /// seek-back so there is no second DB scan. Caller owns and must delete [path].
  Future<StreamedBase> exportBaseToTempFile({
    required String deviceId,
    required List<DeletionLogData> deletions,
    String? epochId,
    String? uploadNonce,
    int? seq,
    int pageSize = 2000,
    DateTime Function() now = DateTime.now,
    Future<Directory> Function()? tempDir,
  }) async {
    final dir = await (tempDir?.call() ?? Future.value(Directory.systemTemp));
    final path =
        '${dir.path}/ssv1_base_${deviceId}_${seq ?? 0}.${_baseTempUuid.v4()}.json';
    final raf = await File(path).open(mode: FileMode.write);
    final digestSink = _Sha256DigestSink();
    final dataHash = sha256.startChunkedConversion(digestSink);
    final exportedAt = now().millisecondsSinceEpoch;
    String? maxRowHlc;
    var rowCount = 0;

    // Writes + hashes only the `data` object bytes (matches _computeChecksum,
    // which hashes jsonEncode(data.toJson())).
    Future<void> writeData(String s) async {
      final bytes = utf8.encode(s);
      dataHash.add(bytes);
      await raf.writeFrom(bytes);
    }

    try {
      // Header up to (but not including) the checksum value.
      await raf.writeString(
        '{"version":$syncFormatVersion,"exportedAt":$exportedAt,'
        '"deviceId":${jsonEncode(deviceId)},"lastSyncTimestamp":null,'
        '"checksum":"',
      );
      final checksumOffset = await raf.position();
      await raf.writeFrom(List.filled(64, 0x30)); // '0'*64 placeholder
      await raf.writeString('","data":');

      // ---- data object (hashed) ----
      await writeData('{');
      final tables = _baseTables;
      for (var t = 0; t < tables.length; t++) {
        final spec = tables[t];
        if (t > 0) await writeData(',');
        await writeData('${jsonEncode(spec.key)}:[');
        var firstRow = true;

        Future<void> emit(Map<String, dynamic> row) async {
          if (!firstRow) await writeData(',');
          firstRow = false;
          rowCount++;
          final hlc = row['hlc'];
          if (hlc is String &&
              (maxRowHlc == null || hlc.compareTo(maxRowHlc!) > 0)) {
            maxRowHlc = hlc;
          }
          await writeData(jsonEncode(row));
        }

        if (spec.table != null) {
          String? cursor;
          while (true) {
            final rows = await _pageBaseTableById(
              spec.table!,
              cursor: cursor,
              limit: pageSize,
              blob: spec.blob,
            );
            for (final row in rows) {
              await emit(row);
            }
            if (rows.length < pageSize) break;
            cursor = rows.last['id'] as String;
          }
        } else {
          for (final row in await spec.full!()) {
            await emit(row);
          }
        }
        await writeData(']');
      }
      await writeData('}');

      // ---- trailer (not part of the data checksum) ----
      final toHlc = _maxHlc([maxRowHlc, ...deletions.map((d) => d.hlc)]);
      final tail = <String, dynamic>{
        'deletions': _groupDeletions(
          deletions,
        ).map((k, v) => MapEntry(k, v.map((d) => d.toJson()).toList())),
        'uploadNonce': uploadNonce,
        'epochId': epochId,
        'seq': seq,
        'baseSeq': null,
        'sinceHlc': null,
        'toHlc': toHlc,
      };
      final tailBuf = StringBuffer();
      tail.forEach(
        (k, v) => tailBuf.write(',${jsonEncode(k)}:${jsonEncode(v)}'),
      );
      tailBuf.write('}');
      await raf.writeString(tailBuf.toString());

      // ---- patch the checksum placeholder with the real data digest ----
      dataHash.close();
      final endPos = await raf.position();
      await raf.setPosition(checksumOffset);
      await raf.writeFrom(utf8.encode(digestSink.value.toString()));
      await raf.setPosition(endPos);
      await raf.flush();
      await raf.close();

      final byteLength = await File(path).length();
      return (
        path: path,
        byteLength: byteLength,
        exportedAt: exportedAt,
        toHlc: toHlc,
        rowCount: rowCount,
      );
    } catch (_) {
      await raf.close();
      try {
        await File(path).delete();
      } catch (_) {}
      rethrow;
    }
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
      diveDiveTypes: await _safeExport(
        'diveDiveTypes',
        () => _exportDiveDiveTypes(hlcSince),
      ),
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
      case 'diveDiveTypes':
        final row = await (_db.select(
          _db.diveDiveTypes,
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

  /// Batched [fetchRecord] for the `hasUpdatedAt` (LWW) entities the merge
  /// compares against: local rows keyed by record id, fetched with one
  /// `WHERE id IN (...)` select. Mirrors [fetchRecord] per entity --
  /// `settings` keys on its `key` column and `certifications` carries a BLOB.
  /// Any other entity (the clockless composite-key junctions, which the merge
  /// never fetches) falls back to a per-id loop so the method stays total.
  Future<Map<String, Map<String, dynamic>>> fetchRecords(
    String entityType,
    Iterable<String> ids,
  ) async {
    final idList = ids.toList();
    if (idList.isEmpty) return {};
    // Chunk to stay under SQLite's bound-variable limit (~999): a large
    // changeset apply can pass thousands of ids, which would overflow a single
    // `WHERE id IN (...)` with "too many SQL variables". Each chunk recurses to
    // the per-entity switch below (a slice <= idChunk skips this branch).
    const idChunk = 900;
    if (idList.length > idChunk) {
      final merged = <String, Map<String, dynamic>>{};
      for (var i = 0; i < idList.length; i += idChunk) {
        final end = (i + idChunk < idList.length) ? i + idChunk : idList.length;
        merged.addAll(await fetchRecords(entityType, idList.sublist(i, end)));
      }
      return merged;
    }
    switch (entityType) {
      case 'divers':
        final rows = await (_db.select(
          _db.divers,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'diverSettings':
        final rows = await (_db.select(
          _db.diverSettings,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'dives':
        final rows = await (_db.select(
          _db.dives,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'diveSites':
        final rows = await (_db.select(
          _db.diveSites,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'equipment':
        final rows = await (_db.select(
          _db.equipment,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'equipmentSets':
        final rows = await (_db.select(
          _db.equipmentSets,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'buddies':
        final rows = await (_db.select(
          _db.buddies,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'diveCenters':
        final rows = await (_db.select(
          _db.diveCenters,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'trips':
        final rows = await (_db.select(
          _db.trips,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'liveaboardDetails':
        final rows = await (_db.select(
          _db.liveaboardDetailRecords,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'itineraryDays':
        final rows = await (_db.select(
          _db.tripItineraryDays,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'diveTypes':
        final rows = await (_db.select(
          _db.diveTypes,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'tankPresets':
        final rows = await (_db.select(
          _db.tankPresets,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'diveComputers':
        final rows = await (_db.select(
          _db.diveComputers,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'tags':
        final rows = await (_db.select(
          _db.tags,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'courses':
        final rows = await (_db.select(
          _db.courses,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'serviceRecords':
        final rows = await (_db.select(
          _db.serviceRecords,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'csvPresets':
        final rows = await (_db.select(
          _db.csvPresets,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'viewConfigs':
        final rows = await (_db.select(
          _db.viewConfigs,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'certifications':
        final rows = await (_db.select(
          _db.certifications,
        )..where((t) => t.id.isIn(idList))).get();
        return {
          for (final r in rows) r.id: r.toJson(serializer: _syncBlobSerializer),
        };
      case 'settings':
        final rows = await (_db.select(
          _db.settings,
        )..where((t) => t.key.isIn(idList))).get();
        return {for (final r in rows) r.key: r.toJson()};
      default:
        // Clockless / composite-key entities are never fetched by the merge;
        // fall back to per-id reads so the method is total and correct.
        final out = <String, Map<String, dynamic>>{};
        for (final id in idList) {
          final row = await fetchRecord(entityType, id);
          if (row != null) out[id] = row;
        }
        return out;
    }
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
      case 'diveDiveTypes':
        await _db
            .into(_db.diveDiveTypes)
            .insertOnConflictUpdate(DiveDiveType.fromJson(data));
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

  /// Batched [upsertRecord]: writes all [records] for [entityType] in one Drift
  /// `batch()` (reused prepared statements), in list order, with identical
  /// conflict semantics. Mirrors [upsertRecord]'s per-entity logic per record --
  /// the same `<Type>.fromJson`, the same per-record transforms, and the same
  /// `settings` device-local-key filter.
  Future<void> upsertRecords(
    String entityType,
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) return;
    switch (entityType) {
      case 'divers':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.divers,
            records.map((r) => Diver.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diverSettings':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diverSettings,
            records
                .map(
                  (r) => DiverSetting.fromJson(_applyDiverSettingDefaults(r)),
                )
                .toList(),
          ),
        );
        return;
      case 'dives':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.dives,
            records.map((r) => Dive.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveProfiles':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveProfiles,
            records.map((r) => DiveProfile.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveTanks':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveTanks,
            records.map((r) => DiveTank.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveEquipment':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveEquipment,
            records.map((r) => DiveEquipmentData.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveWeights':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveWeights,
            records.map((r) => DiveWeight.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveSites':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveSites,
            records.map((r) => DiveSite.fromJson(r)).toList(),
          ),
        );
        return;
      case 'equipment':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipment,
            records.map((r) => EquipmentData.fromJson(r)).toList(),
          ),
        );
        return;
      case 'equipmentSets':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipmentSets,
            records.map((r) => EquipmentSet.fromJson(r)).toList(),
          ),
        );
        return;
      case 'equipmentSetItems':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipmentSetItems,
            records.map((r) => EquipmentSetItem.fromJson(r)).toList(),
          ),
        );
        return;
      case 'media':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.media,
            records
                .map(
                  (r) => MediaData.fromJson(r, serializer: _syncBlobSerializer),
                )
                .toList(),
          ),
        );
        return;
      case 'buddies':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.buddies,
            records.map((r) => Buddy.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveBuddies':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveBuddies,
            records.map((r) => DiveBuddy.fromJson(r)).toList(),
          ),
        );
        return;
      case 'certifications':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.certifications,
            records
                .map(
                  (r) => Certification.fromJson(
                    r,
                    serializer: _syncBlobSerializer,
                  ),
                )
                .toList(),
          ),
        );
        return;
      case 'courses':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.courses,
            records.map((r) => Course.fromJson(r)).toList(),
          ),
        );
        return;
      case 'serviceRecords':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.serviceRecords,
            records.map((r) => ServiceRecord.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveCenters':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveCenters,
            records.map((r) => DiveCenter.fromJson(r)).toList(),
          ),
        );
        return;
      case 'trips':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.trips,
            records.map((r) => Trip.fromJson(r)).toList(),
          ),
        );
        return;
      case 'liveaboardDetails':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.liveaboardDetailRecords,
            records.map((r) => LiveaboardDetailRecord.fromJson(r)).toList(),
          ),
        );
        return;
      case 'itineraryDays':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.tripItineraryDays,
            records.map((r) => TripItineraryDay.fromJson(r)).toList(),
          ),
        );
        return;
      case 'tags':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.tags,
            records.map((r) => Tag.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveTags':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveTags,
            records.map((r) => DiveTag.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveDiveTypes':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveDiveTypes,
            records.map((r) => DiveDiveType.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveTypes':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveTypes,
            records.map((r) => DiveType.fromJson(r)).toList(),
          ),
        );
        return;
      case 'tankPresets':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.tankPresets,
            records.map((r) => TankPreset.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveComputers':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveComputers,
            records.map((r) => DiveComputer.fromJson(r)).toList(),
          ),
        );
        return;
      case 'tankPressureProfiles':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.tankPressureProfiles,
            records.map((r) => TankPressureProfile.fromJson(r)).toList(),
          ),
        );
        return;
      case 'tideRecords':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.tideRecords,
            records.map((r) => TideRecord.fromJson(r)).toList(),
          ),
        );
        return;
      case 'settings':
        // Mirror upsertRecord: never overwrite a device-local settings key.
        final settingsRows = records
            .where((r) => !_deviceLocalSettingsKeys.contains(r['key']))
            .map((r) => Setting.fromJson(r))
            .toList();
        if (settingsRows.isEmpty) return;
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(_db.settings, settingsRows),
        );
        return;
      case 'species':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.species,
            records.map((r) => Specy.fromJson(r)).toList(),
          ),
        );
        return;
      case 'sightings':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.sightings,
            records.map((r) => Sighting.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveProfileEvents':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveProfileEvents,
            records
                .map(
                  (r) => DiveProfileEvent.fromJson(
                    r['source'] == null ? {...r, 'source': 'imported'} : r,
                  ),
                )
                .toList(),
          ),
        );
        return;
      case 'gasSwitches':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.gasSwitches,
            records.map((r) => GasSwitche.fromJson(r)).toList(),
          ),
        );
        return;
      case 'diveCustomFields':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveCustomFields,
            records
                .map((r) => DiveCustomField.fromJson(_withTimestampDefaults(r)))
                .toList(),
          ),
        );
        return;
      case 'diveDataSources':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveDataSources,
            records
                .map(
                  (r) => DiveDataSourcesData.fromJson(
                    _withTimestampDefaults(r),
                    serializer: _syncBlobSerializer,
                  ),
                )
                .toList(),
          ),
        );
        return;
      case 'siteSpecies':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.siteSpecies,
            records
                .map((r) => SiteSpecy.fromJson(_withTimestampDefaults(r)))
                .toList(),
          ),
        );
        return;
      case 'csvPresets':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.csvPresets,
            records
                .map((r) => CsvPreset.fromJson(_withTimestampDefaults(r)))
                .toList(),
          ),
        );
        return;
      case 'viewConfigs':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.viewConfigs,
            records
                .map((r) => ViewConfig.fromJson(_withTimestampDefaults(r)))
                .toList(),
          ),
        );
        return;
      case 'fieldPresets':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.fieldPresets,
            records
                .map((r) => FieldPreset.fromJson(_withTimestampDefaults(r)))
                .toList(),
          ),
        );
        return;
      default:
        throw ArgumentError('upsertRecords: unknown entityType $entityType');
    }
  }

  /// Every local row id for [entityType], in the id form [deleteRecord]
  /// accepts: plain `id` for most entities, `key` for `settings`, and the
  /// composite `a|b` form (matching [_compositeId]) for the two junction
  /// tables. Reads only the id column(s) -- never full rows -- so the streaming
  /// replace-adopt can enumerate row-per-sample tables (diveProfiles,
  /// tankPressureProfiles) to delete local rows absent from the restored
  /// library (#358) without materializing their payloads. Memory still scales
  /// with the entity's row count (the result is a Set of ids and `get()` loads
  /// all id rows at once), but ids are orders of magnitude smaller than the
  /// rows they stand in for. Mirrors the entity -> table mapping in
  /// [upsertRecord] / [deleteRecord], and THROWS on an entity with no case so a
  /// newly added synced entity that forgets one fails loudly rather than
  /// silently skipping its stale-row deletion (asserted by the
  /// "every synced entity" test).
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
      case 'diveDiveTypes':
        return plain(_db.diveDiveTypes, _db.diveDiveTypes.id);
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
      case 'media':
        return plain(_db.media, _db.media.id);
      default:
        // Fail loud: a synced entity without a case here would silently
        // enumerate zero local ids, so streaming adopt would never delete its
        // stale rows. Callers only pass entityHasUpdatedAt keys, all of which
        // have a case (asserted by sync_data_serializer_record_ids_test.dart).
        throw ArgumentError.value(
          entityType,
          'entityType',
          'recordIdsFor has no case for this synced entity',
        );
    }
  }

  /// Delete every row of the table backing [entityType]. Used by streaming
  /// Replace-adopt (#358): clearing each table then re-inserting the cloud
  /// union is equivalent to upsert-then-delete-not-in-cloud but needs no in-RAM
  /// id set to diff against, so adopt memory stays bounded regardless of size.
  ///
  /// Device-local settings keys ([_deviceLocalSettingsKeys], e.g.
  /// `active_diver_id`) are preserved: they are never part of a synced or
  /// replaced library, so an adopt must not wipe them (they are also excluded
  /// from the base by [_exportSettings], so re-insert would not restore them).
  Future<void> deleteAllRecords(String entityType) async {
    if (entityType == 'settings') {
      await (_db.delete(
        _db.settings,
      )..where((t) => t.key.isNotIn(_deviceLocalSettingsKeys.toList()))).go();
      return;
    }
    await _db.delete(_syncTableFor(entityType)).go();
  }

  /// The Drift table backing a synced [entityType] (mirrors recordIdsFor).
  TableInfo<Table, dynamic> _syncTableFor(String entityType) {
    switch (entityType) {
      case 'settings':
        return _db.settings;
      case 'diveEquipment':
        return _db.diveEquipment;
      case 'equipmentSetItems':
        return _db.equipmentSetItems;
      case 'divers':
        return _db.divers;
      case 'diverSettings':
        return _db.diverSettings;
      case 'buddies':
        return _db.buddies;
      case 'diveCenters':
        return _db.diveCenters;
      case 'trips':
        return _db.trips;
      case 'liveaboardDetails':
        return _db.liveaboardDetailRecords;
      case 'itineraryDays':
        return _db.tripItineraryDays;
      case 'equipment':
        return _db.equipment;
      case 'equipmentSets':
        return _db.equipmentSets;
      case 'diveTypes':
        return _db.diveTypes;
      case 'tankPresets':
        return _db.tankPresets;
      case 'diveComputers':
        return _db.diveComputers;
      case 'species':
        return _db.species;
      case 'tags':
        return _db.tags;
      case 'courses':
        return _db.courses;
      case 'dives':
        return _db.dives;
      case 'diveSites':
        return _db.diveSites;
      case 'diveTanks':
        return _db.diveTanks;
      case 'diveWeights':
        return _db.diveWeights;
      case 'diveTags':
        return _db.diveTags;
      case 'diveDiveTypes':
        return _db.diveDiveTypes;
      case 'diveBuddies':
        return _db.diveBuddies;
      case 'diveProfiles':
        return _db.diveProfiles;
      case 'diveProfileEvents':
        return _db.diveProfileEvents;
      case 'gasSwitches':
        return _db.gasSwitches;
      case 'diveCustomFields':
        return _db.diveCustomFields;
      case 'diveDataSources':
        return _db.diveDataSources;
      case 'siteSpecies':
        return _db.siteSpecies;
      case 'csvPresets':
        return _db.csvPresets;
      case 'viewConfigs':
        return _db.viewConfigs;
      case 'fieldPresets':
        return _db.fieldPresets;
      case 'tankPressureProfiles':
        return _db.tankPressureProfiles;
      case 'tideRecords':
        return _db.tideRecords;
      case 'sightings':
        return _db.sightings;
      case 'certifications':
        return _db.certifications;
      case 'serviceRecords':
        return _db.serviceRecords;
      case 'media':
        return _db.media;
      default:
        throw ArgumentError.value(
          entityType,
          'entityType',
          '_syncTableFor has no case for this synced entity',
        );
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
      case 'diveDiveTypes':
        await (_db.delete(
          _db.diveDiveTypes,
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

  Future<List<Map<String, dynamic>>> _exportDiveDiveTypes(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final diveIds = modifiedDives.map((d) => d.id).toSet();
      if (diveIds.isEmpty) return [];

      final rows = await (_db.select(
        _db.diveDiveTypes,
      )..where((t) => t.diveId.isIn(diveIds))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveDiveTypes).get();
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
      'showAscentRateColors': false,
      'showNdlOnProfile': true,
      'lastStopDepth': 3.0,
      'decoStopIncrement': 3.0,
      'ascentGasSet': 0,
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
      // Dive profile default-visible metrics. Non-nullable bool added in v91;
      // seed it so payloads predating the column hydrate instead of throwing in
      // DiverSetting.fromJson.
      'defaultShowAscentRateLine': false,
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

/// Captures the single digest a chunked SHA-256 conversion emits at close.
/// Mirrors the sink in base_part_file_sink.dart (crypto does not export
/// AccumulatorSink).
class _Sha256DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
