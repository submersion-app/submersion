import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/dive.dart' as domain;
import '../../domain/entities/dive_weight.dart' as domain;
import '../../../dive_centers/domain/entities/dive_center.dart' as domain;
import '../../../dive_sites/domain/entities/dive_site.dart' as domain;
import '../../../equipment/domain/entities/equipment_item.dart';
import '../../../tags/domain/entities/tag.dart' as domain;
import '../../../tags/data/repositories/tag_repository.dart';

class DiveRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveRepository);
  final TagRepository _tagRepository = TagRepository();

  // ============================================================================
  // CRUD Operations
  // ============================================================================

  /// Get all dives, ordered by date (newest first)
  /// This method is optimized to avoid N+1 queries by batch loading related data
  Future<List<domain.Dive>> getAllDives() async {
    try {
      final query = _db.select(_db.dives)
        ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

      final rows = await query.get();
      if (rows.isEmpty) return [];

    // Batch load all related data to avoid N+1 queries
    final diveIds = rows.map((r) => r.id).toList();

    // Load all tanks for these dives in one query
    final allTanks = await (_db.select(_db.diveTanks)
          ..where((t) => t.diveId.isIn(diveIds))
          ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
        .get();
    final tanksByDive = <String, List<DiveTank>>{};
    for (final tank in allTanks) {
      tanksByDive.putIfAbsent(tank.diveId, () => []).add(tank);
    }

    // Load all sites for these dives in one query
    final siteIds = rows.where((r) => r.siteId != null).map((r) => r.siteId!).toSet().toList();
    final allSites = siteIds.isNotEmpty
        ? await (_db.select(_db.diveSites)..where((t) => t.id.isIn(siteIds))).get()
        : <DiveSite>[];
    final sitesById = {for (final s in allSites) s.id: s};

    // Load all dive centers for these dives in one query
    final centerIds = rows.where((r) => r.diveCenterId != null).map((r) => r.diveCenterId!).toSet().toList();
    final allCenters = centerIds.isNotEmpty
        ? await (_db.select(_db.diveCenters)..where((t) => t.id.isIn(centerIds))).get()
        : <DiveCenter>[];
    final centersById = {for (final c in allCenters) c.id: c};

    // Load all equipment for these dives in one query
    final allDiveEquipment = await (_db.select(_db.diveEquipment).join([
      innerJoin(_db.equipment, _db.equipment.id.equalsExp(_db.diveEquipment.equipmentId)),
    ])
          ..where(_db.diveEquipment.diveId.isIn(diveIds)))
        .get();
    final equipmentByDive = <String, List<EquipmentItem>>{};
    for (final joinRow in allDiveEquipment) {
      final diveId = joinRow.readTable(_db.diveEquipment).diveId;
      final e = joinRow.readTable(_db.equipment);
      equipmentByDive.putIfAbsent(diveId, () => []).add(EquipmentItem(
        id: e.id,
        name: e.name,
        type: EquipmentType.values.firstWhere(
          (t) => t.name == e.type,
          orElse: () => EquipmentType.other,
        ),
        brand: e.brand,
        model: e.model,
        serialNumber: e.serialNumber,
        size: e.size,
        status: EquipmentStatus.values.firstWhere(
          (s) => s.name == e.status,
          orElse: () => EquipmentStatus.active,
        ),
        purchaseDate: e.purchaseDate != null
            ? DateTime.fromMillisecondsSinceEpoch(e.purchaseDate!)
            : null,
        purchasePrice: e.purchasePrice,
        purchaseCurrency: e.purchaseCurrency,
        lastServiceDate: e.lastServiceDate != null
            ? DateTime.fromMillisecondsSinceEpoch(e.lastServiceDate!)
            : null,
        serviceIntervalDays: e.serviceIntervalDays,
        notes: e.notes,
        isActive: e.isActive,
      ),);
    }

    // Note: Profile data is NOT loaded for list views to improve performance
    // Profile data should only be loaded for individual dive detail views

    // Load all tags for these dives in one query
    final tagsByDive = await _tagRepository.getTagsForDives(diveIds);

      return rows.map((row) => _mapRowToDiveWithPreloadedData(
            row,
            tanks: tanksByDive[row.id] ?? [],
            equipment: equipmentByDive[row.id] ?? [],
            site: row.siteId != null ? sitesById[row.siteId] : null,
            center: row.diveCenterId != null ? centersById[row.diveCenterId] : null,
            tags: tagsByDive[row.id] ?? [],
          ),).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all dives', e, stackTrace);
      rethrow;
    }
  }

  /// Get a single dive by ID
  Future<domain.Dive?> getDiveById(String id) async {
    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      if (row == null) return null;

      return _mapRowToDive(row);
    } catch (e, stackTrace) {
      _log.error('Failed to get dive by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new dive
  Future<domain.Dive> createDive(domain.Dive dive) async {
    try {
      _log.info('Creating dive: ${dive.diveNumber ?? "new"}');
      final id = dive.id.isEmpty ? _uuid.v4() : dive.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.into(_db.dives).insert(DivesCompanion(
      id: Value(id),
      diveNumber: Value(dive.diveNumber),
      diveDateTime: Value(dive.dateTime.millisecondsSinceEpoch),
      entryTime: Value(dive.entryTime?.millisecondsSinceEpoch),
      exitTime: Value(dive.exitTime?.millisecondsSinceEpoch),
      duration: Value(dive.duration?.inSeconds),
      maxDepth: Value(dive.maxDepth),
      avgDepth: Value(dive.avgDepth),
      waterTemp: Value(dive.waterTemp),
      airTemp: Value(dive.airTemp),
      visibility: Value(dive.visibility?.name),
      diveType: Value(dive.diveTypeId),
      buddy: Value(dive.buddy),
      diveMaster: Value(dive.diveMaster),
      notes: Value(dive.notes),
      siteId: Value(dive.site?.id),
      diveCenterId: Value(dive.diveCenter?.id),
      tripId: Value(dive.tripId ?? dive.trip?.id),
      rating: Value(dive.rating),
      // Conditions fields
      currentDirection: Value(dive.currentDirection?.name),
      currentStrength: Value(dive.currentStrength?.name),
      swellHeight: Value(dive.swellHeight),
      entryMethod: Value(dive.entryMethod?.name),
      exitMethod: Value(dive.exitMethod?.name),
      waterType: Value(dive.waterType?.name),
      // Weight system fields
      weightAmount: Value(dive.weightAmount),
      weightType: Value(dive.weightType?.name),
      // Favorite flag
      isFavorite: Value(dive.isFavorite),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),);

    // Insert tanks
    for (final tank in dive.tanks) {
      await _db.into(_db.diveTanks).insert(DiveTanksCompanion(
        id: Value(_uuid.v4()),
        diveId: Value(id),
        volume: Value(tank.volume),
        workingPressure: Value(tank.workingPressure),
        startPressure: Value(tank.startPressure),
        endPressure: Value(tank.endPressure),
        o2Percent: Value(tank.gasMix.o2),
        hePercent: Value(tank.gasMix.he),
        tankOrder: Value(tank.order),
        tankRole: Value(tank.role.name),
        tankMaterial: Value(tank.material?.name),
        tankName: Value(tank.name),
      ),);
    }

    // Insert weights
    for (final weight in dive.weights) {
      await _db.into(_db.diveWeights).insert(DiveWeightsCompanion(
        id: Value(weight.id.isNotEmpty ? weight.id : _uuid.v4()),
        diveId: Value(id),
        weightType: Value(weight.weightType.name),
        amountKg: Value(weight.amountKg),
        notes: Value(weight.notes),
        createdAt: Value(now),
      ),);
    }

    // Insert profile points
    for (final point in dive.profile) {
      await _db.into(_db.diveProfiles).insert(DiveProfilesCompanion(
        id: Value(_uuid.v4()),
        diveId: Value(id),
        timestamp: Value(point.timestamp),
        depth: Value(point.depth),
        pressure: Value(point.pressure),
        temperature: Value(point.temperature),
        heartRate: Value(point.heartRate),
      ),);
    }

      // Insert equipment associations
      for (final item in dive.equipment) {
        await _db.into(_db.diveEquipment).insert(DiveEquipmentCompanion(
          diveId: Value(id),
          equipmentId: Value(item.id),
        ),);
      }

      // Insert tag associations
      if (dive.tags.isNotEmpty) {
        await _tagRepository.setTagsForDive(id, dive.tags);
      }

      _log.info('Created dive with id: $id');
      return dive.copyWith(id: id);
    } catch (e, stackTrace) {
      _log.error('Failed to create dive', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing dive
  Future<void> updateDive(domain.Dive dive) async {
    try {
      _log.info('Updating dive: ${dive.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

    await (_db.update(_db.dives)..where((t) => t.id.equals(dive.id))).write(
      DivesCompanion(
        diveNumber: Value(dive.diveNumber),
        diveDateTime: Value(dive.dateTime.millisecondsSinceEpoch),
        entryTime: Value(dive.entryTime?.millisecondsSinceEpoch),
        exitTime: Value(dive.exitTime?.millisecondsSinceEpoch),
        duration: Value(dive.duration?.inSeconds),
        maxDepth: Value(dive.maxDepth),
        avgDepth: Value(dive.avgDepth),
        waterTemp: Value(dive.waterTemp),
        airTemp: Value(dive.airTemp),
        visibility: Value(dive.visibility?.name),
        diveType: Value(dive.diveTypeId),
        buddy: Value(dive.buddy),
        diveMaster: Value(dive.diveMaster),
        notes: Value(dive.notes),
        siteId: Value(dive.site?.id),
        diveCenterId: Value(dive.diveCenter?.id),
        tripId: Value(dive.tripId ?? dive.trip?.id),
        rating: Value(dive.rating),
        // Conditions fields
        currentDirection: Value(dive.currentDirection?.name),
        currentStrength: Value(dive.currentStrength?.name),
        swellHeight: Value(dive.swellHeight),
        entryMethod: Value(dive.entryMethod?.name),
        exitMethod: Value(dive.exitMethod?.name),
        waterType: Value(dive.waterType?.name),
        // Weight system fields
        weightAmount: Value(dive.weightAmount),
        weightType: Value(dive.weightType?.name),
        // Favorite flag
        isFavorite: Value(dive.isFavorite),
        updatedAt: Value(now),
      ),
    );

    // Update tanks: delete and re-insert
    await (_db.delete(_db.diveTanks)..where((t) => t.diveId.equals(dive.id))).go();
    for (final tank in dive.tanks) {
      await _db.into(_db.diveTanks).insert(DiveTanksCompanion(
        id: Value(_uuid.v4()),
        diveId: Value(dive.id),
        volume: Value(tank.volume),
        workingPressure: Value(tank.workingPressure),
        startPressure: Value(tank.startPressure),
        endPressure: Value(tank.endPressure),
        o2Percent: Value(tank.gasMix.o2),
        hePercent: Value(tank.gasMix.he),
        tankOrder: Value(tank.order),
        tankRole: Value(tank.role.name),
        tankMaterial: Value(tank.material?.name),
        tankName: Value(tank.name),
      ),);
    }

      // Update weights: delete and re-insert
      await (_db.delete(_db.diveWeights)..where((t) => t.diveId.equals(dive.id))).go();
      for (final weight in dive.weights) {
        await _db.into(_db.diveWeights).insert(DiveWeightsCompanion(
          id: Value(weight.id.isNotEmpty ? weight.id : _uuid.v4()),
          diveId: Value(dive.id),
          weightType: Value(weight.weightType.name),
          amountKg: Value(weight.amountKg),
          notes: Value(weight.notes),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),);
      }

      // Update equipment: delete and re-insert
      await (_db.delete(_db.diveEquipment)..where((t) => t.diveId.equals(dive.id))).go();
      for (final item in dive.equipment) {
        await _db.into(_db.diveEquipment).insert(DiveEquipmentCompanion(
          diveId: Value(dive.id),
          equipmentId: Value(item.id),
        ),);
      }

      // Update tags
      await _tagRepository.setTagsForDive(dive.id, dive.tags);

      _log.info('Updated dive: ${dive.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update dive: ${dive.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a dive
  Future<void> deleteDive(String id) async {
    try {
      _log.info('Deleting dive: $id');
      await (_db.delete(_db.dives)..where((t) => t.id.equals(id))).go();
      _log.info('Deleted dive: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete dive: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Bulk delete multiple dives
  /// Returns the list of deleted dive IDs for potential undo
  Future<List<String>> bulkDeleteDives(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      _log.info('Bulk deleting ${ids.length} dives');
      await (_db.delete(_db.dives)..where((t) => t.id.isIn(ids))).go();
      _log.info('Bulk deleted ${ids.length} dives');
      return ids;
    } catch (e, stackTrace) {
      _log.error('Failed to bulk delete dives', e, stackTrace);
      rethrow;
    }
  }

  /// Get dives by their IDs (for undo functionality)
  Future<List<domain.Dive>> getDivesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.id.isIn(ids))
        ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

      final rows = await query.get();
      return Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error('Failed to get dives by ids', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Query Operations
  // ============================================================================

  /// Get dives for a specific site
  Future<List<domain.Dive>> getDivesForSite(String siteId) async {
    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.siteId.equals(siteId))
        ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

      final rows = await query.get();
      return Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error('Failed to get dives for site: $siteId', e, stackTrace);
      rethrow;
    }
  }

  /// Get dives within a date range
  Future<List<domain.Dive>> getDivesInRange(DateTime start, DateTime end) async {
    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.diveDateTime.isBiggerOrEqualValue(start.millisecondsSinceEpoch))
        ..where((t) => t.diveDateTime.isSmallerOrEqualValue(end.millisecondsSinceEpoch))
        ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

      final rows = await query.get();
      return Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error('Failed to get dives in range: $start - $end', e, stackTrace);
      rethrow;
    }
  }

  /// Get the next dive number
  Future<int> getNextDiveNumber() async {
    try {
      final result = await _db.customSelect(
        'SELECT MAX(dive_number) as max_num FROM dives',
      ).getSingle();

      final maxNum = result.data['max_num'] as int?;
      return (maxNum ?? 0) + 1;
    } catch (e, stackTrace) {
      _log.error('Failed to get next dive number', e, stackTrace);
      rethrow;
    }
  }

  /// Search dives by notes or buddy name
  Future<List<domain.Dive>> searchDives(String query) async {
    try {
      final searchQuery = _db.select(_db.dives)
        ..where((t) =>
            t.notes.contains(query) |
            t.buddy.contains(query) |
            t.diveMaster.contains(query),)
        ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

      final rows = await searchQuery.get();
      return Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error('Failed to search dives: $query', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Statistics
  // ============================================================================

  Future<DiveStatistics> getStatistics() async {
    try {
      // Basic stats
    final stats = await _db.customSelect('''
      SELECT
        COUNT(*) as total_dives,
        SUM(duration) as total_time,
        MAX(max_depth) as max_depth,
        AVG(max_depth) as avg_max_depth,
        AVG(water_temp) as avg_temp,
        COUNT(DISTINCT site_id) as total_sites
      FROM dives
    ''').getSingle();

    // Dives by month (last 12 months)
    final monthlyStats = await _db.customSelect('''
      SELECT
        strftime('%Y', dive_date_time / 1000, 'unixepoch') as year,
        strftime('%m', dive_date_time / 1000, 'unixepoch') as month,
        COUNT(*) as count
      FROM dives
      WHERE dive_date_time >= strftime('%s', 'now', '-12 months') * 1000
      GROUP BY year, month
      ORDER BY year, month
    ''').get();

    final divesByMonth = monthlyStats.map((row) => MonthlyDiveCount(
      year: int.parse(row.data['year'] as String),
      month: int.parse(row.data['month'] as String),
      count: row.data['count'] as int,
    ),).toList();

    // Depth distribution
    final depthStats = await _db.customSelect('''
      SELECT
        CASE
          WHEN max_depth < 10 THEN '0-10m'
          WHEN max_depth < 20 THEN '10-20m'
          WHEN max_depth < 30 THEN '20-30m'
          WHEN max_depth < 40 THEN '30-40m'
          ELSE '40m+'
        END as depth_range,
        COUNT(*) as count
      FROM dives
      WHERE max_depth IS NOT NULL
      GROUP BY depth_range
      ORDER BY
        CASE depth_range
          WHEN '0-10m' THEN 1
          WHEN '10-20m' THEN 2
          WHEN '20-30m' THEN 3
          WHEN '30-40m' THEN 4
          ELSE 5
        END
    ''').get();

    final depthRanges = [
      DepthRangeStat(label: '0-10m', minDepth: 0, maxDepth: 10, count: 0),
      DepthRangeStat(label: '10-20m', minDepth: 10, maxDepth: 20, count: 0),
      DepthRangeStat(label: '20-30m', minDepth: 20, maxDepth: 30, count: 0),
      DepthRangeStat(label: '30-40m', minDepth: 30, maxDepth: 40, count: 0),
      DepthRangeStat(label: '40m+', minDepth: 40, maxDepth: 100, count: 0),
    ];

    final depthDistribution = depthRanges.map((range) {
      final found = depthStats.where((row) => row.data['depth_range'] == range.label);
      return DepthRangeStat(
        label: range.label,
        minDepth: range.minDepth,
        maxDepth: range.maxDepth,
        count: found.isNotEmpty ? found.first.data['count'] as int : 0,
      );
    }).toList();

    // Top sites
    final siteStats = await _db.customSelect('''
      SELECT
        s.name as site_name,
        COUNT(*) as dive_count
      FROM dives d
      INNER JOIN dive_sites s ON d.site_id = s.id
      GROUP BY d.site_id
      ORDER BY dive_count DESC
      LIMIT 5
    ''').get();

    final topSites = siteStats.map((row) => TopSiteStat(
      siteName: row.data['site_name'] as String,
      diveCount: row.data['dive_count'] as int,
    ),).toList();

      return DiveStatistics(
        totalDives: stats.data['total_dives'] as int? ?? 0,
        totalTimeSeconds: stats.data['total_time'] as int? ?? 0,
        maxDepth: stats.data['max_depth'] as double? ?? 0,
        avgMaxDepth: stats.data['avg_max_depth'] as double? ?? 0,
        avgTemperature: stats.data['avg_temp'] as double?,
        totalSites: stats.data['total_sites'] as int? ?? 0,
        divesByMonth: divesByMonth,
        depthDistribution: depthDistribution,
        topSites: topSites,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get statistics', e, stackTrace);
      rethrow;
    }
  }

  /// Get dive records (superlatives)
  Future<DiveRecords> getRecords() async {
    try {
      // Deepest dive
    final deepestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE d.max_depth IS NOT NULL
      ORDER BY d.max_depth DESC
      LIMIT 1
    ''').getSingleOrNull();

    // Longest dive
    final longestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE d.duration IS NOT NULL
      ORDER BY d.duration DESC
      LIMIT 1
    ''').getSingleOrNull();

    // Coldest dive
    final coldestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE d.water_temp IS NOT NULL
      ORDER BY d.water_temp ASC
      LIMIT 1
    ''').getSingleOrNull();

    // Warmest dive
    final warmestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE d.water_temp IS NOT NULL
      ORDER BY d.water_temp DESC
      LIMIT 1
    ''').getSingleOrNull();

    // First dive
    final firstResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      ORDER BY d.dive_date_time ASC
      LIMIT 1
    ''').getSingleOrNull();

    // Most recent dive
    final lastResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      ORDER BY d.dive_date_time DESC
      LIMIT 1
    ''').getSingleOrNull();

    // Shallowest dive (with max_depth recorded)
    final shallowestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE d.max_depth IS NOT NULL AND d.max_depth > 0
      ORDER BY d.max_depth ASC
      LIMIT 1
    ''').getSingleOrNull();

      return DiveRecords(
        deepestDive: deepestResult != null ? _mapRecordRow(deepestResult) : null,
        longestDive: longestResult != null ? _mapRecordRow(longestResult) : null,
        coldestDive: coldestResult != null ? _mapRecordRow(coldestResult) : null,
        warmestDive: warmestResult != null ? _mapRecordRow(warmestResult) : null,
        firstDive: firstResult != null ? _mapRecordRow(firstResult) : null,
        lastDive: lastResult != null ? _mapRecordRow(lastResult) : null,
        shallowestDive: shallowestResult != null ? _mapRecordRow(shallowestResult) : null,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get dive records', e, stackTrace);
      rethrow;
    }
  }

  DiveRecord _mapRecordRow(QueryRow row) {
    return DiveRecord(
      diveId: row.data['id'] as String,
      diveNumber: row.data['dive_number'] as int?,
      siteName: row.data['site_name'] as String?,
      dateTime: DateTime.fromMillisecondsSinceEpoch(row.data['dive_date_time'] as int),
      maxDepth: row.data['max_depth'] as double?,
      duration: row.data['duration'] != null
          ? Duration(seconds: row.data['duration'] as int)
          : null,
      waterTemp: row.data['water_temp'] as double?,
    );
  }

  // ============================================================================
  // Mapping Helpers
  // ============================================================================

  /// Map dive row to domain entity with pre-loaded related data (for batch loading)
  domain.Dive _mapRowToDiveWithPreloadedData(
    Dive row, {
    required List<DiveTank> tanks,
    required List<EquipmentItem> equipment,
    DiveSite? site,
    DiveCenter? center,
    List<domain.Tag> tags = const [],
  }) {
    // Map site if exists
    domain.DiveSite? domainSite;
    if (site != null) {
      domainSite = domain.DiveSite(
        id: site.id,
        name: site.name,
        description: site.description,
        location: site.latitude != null && site.longitude != null
            ? domain.GeoPoint(site.latitude!, site.longitude!)
            : null,
        maxDepth: site.maxDepth,
        country: site.country,
        region: site.region,
        rating: site.rating,
        notes: site.notes,
      );
    }

    // Map dive center if exists
    domain.DiveCenter? domainCenter;
    if (center != null) {
      domainCenter = domain.DiveCenter(
        id: center.id,
        name: center.name,
        location: center.location,
        latitude: center.latitude,
        longitude: center.longitude,
        country: center.country,
        phone: center.phone,
        email: center.email,
        website: center.website,
        affiliations: center.affiliations?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? [],
        rating: center.rating,
        notes: center.notes,
        createdAt: DateTime.fromMillisecondsSinceEpoch(center.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(center.updatedAt),
      );
    }

    return domain.Dive(
      id: row.id,
      diveNumber: row.diveNumber,
      dateTime: DateTime.fromMillisecondsSinceEpoch(row.diveDateTime),
      entryTime: row.entryTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.entryTime!)
          : null,
      exitTime: row.exitTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.exitTime!)
          : null,
      duration: row.duration != null ? Duration(seconds: row.duration!) : null,
      maxDepth: row.maxDepth,
      avgDepth: row.avgDepth,
      waterTemp: row.waterTemp,
      airTemp: row.airTemp,
      visibility: row.visibility != null
          ? Visibility.values.firstWhere(
              (v) => v.name == row.visibility,
              orElse: () => Visibility.unknown,
            )
          : null,
      diveTypeId: row.diveType,
      buddy: row.buddy,
      diveMaster: row.diveMaster,
      notes: row.notes,
      site: domainSite,
      diveCenter: domainCenter,
      rating: row.rating,
      currentDirection: row.currentDirection != null
          ? CurrentDirection.values.firstWhere(
              (c) => c.name == row.currentDirection,
              orElse: () => CurrentDirection.none,
            )
          : null,
      currentStrength: row.currentStrength != null
          ? CurrentStrength.values.firstWhere(
              (c) => c.name == row.currentStrength,
              orElse: () => CurrentStrength.none,
            )
          : null,
      swellHeight: row.swellHeight,
      entryMethod: row.entryMethod != null
          ? EntryMethod.values.firstWhere(
              (e) => e.name == row.entryMethod,
              orElse: () => EntryMethod.other,
            )
          : null,
      exitMethod: row.exitMethod != null
          ? EntryMethod.values.firstWhere(
              (e) => e.name == row.exitMethod,
              orElse: () => EntryMethod.other,
            )
          : null,
      waterType: row.waterType != null
          ? WaterType.values.firstWhere(
              (w) => w.name == row.waterType,
              orElse: () => WaterType.salt,
            )
          : null,
      weightAmount: row.weightAmount,
      weightType: row.weightType != null
          ? WeightType.values.firstWhere(
              (w) => w.name == row.weightType,
              orElse: () => WeightType.belt,
            )
          : null,
      tanks: tanks.map((t) => domain.DiveTank(
        id: t.id,
        name: t.tankName,
        volume: t.volume,
        workingPressure: t.workingPressure,
        startPressure: t.startPressure,
        endPressure: t.endPressure,
        gasMix: domain.GasMix(o2: t.o2Percent, he: t.hePercent),
        role: TankRole.values.firstWhere(
          (r) => r.name == t.tankRole,
          orElse: () => TankRole.backGas,
        ),
        material: t.tankMaterial != null
            ? TankMaterial.values.firstWhere(
                (m) => m.name == t.tankMaterial,
                orElse: () => TankMaterial.aluminum,
              )
            : null,
        order: t.tankOrder,
      ),).toList(),
      profile: const [], // Profile not loaded for list views
      equipment: equipment,
      weights: const [], // Weights not loaded for list views (use detail view)
      isFavorite: row.isFavorite,
      tags: tags,
    );
  }

  /// Legacy method that loads all related data for a single dive (used for detail views)
  Future<domain.Dive> _mapRowToDive(Dive row) async {
    // Get tanks for this dive
    final tanksQuery = _db.select(_db.diveTanks)
      ..where((t) => t.diveId.equals(row.id))
      ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]);
    final tankRows = await tanksQuery.get();

    // Get profile for this dive
    final profileQuery = _db.select(_db.diveProfiles)
      ..where((t) => t.diveId.equals(row.id))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    final profileRows = await profileQuery.get();

    // Get equipment for this dive
    final equipmentQuery = _db.select(_db.diveEquipment).join([
      innerJoin(_db.equipment, _db.equipment.id.equalsExp(_db.diveEquipment.equipmentId)),
    ])..where(_db.diveEquipment.diveId.equals(row.id));
    final equipmentRows = await equipmentQuery.get();
    final equipmentItems = equipmentRows.map((joinRow) {
      final e = joinRow.readTable(_db.equipment);
      return EquipmentItem(
        id: e.id,
        name: e.name,
        type: EquipmentType.values.firstWhere(
          (t) => t.name == e.type,
          orElse: () => EquipmentType.other,
        ),
        brand: e.brand,
        model: e.model,
        serialNumber: e.serialNumber,
        size: e.size,
        status: EquipmentStatus.values.firstWhere(
          (s) => s.name == e.status,
          orElse: () => EquipmentStatus.active,
        ),
        purchaseDate: e.purchaseDate != null
            ? DateTime.fromMillisecondsSinceEpoch(e.purchaseDate!)
            : null,
        purchasePrice: e.purchasePrice,
        purchaseCurrency: e.purchaseCurrency,
        lastServiceDate: e.lastServiceDate != null
            ? DateTime.fromMillisecondsSinceEpoch(e.lastServiceDate!)
            : null,
        serviceIntervalDays: e.serviceIntervalDays,
        notes: e.notes,
        isActive: e.isActive,
      );
    }).toList();

    // Get weights for this dive
    final weights = await _loadWeightsForDive(row.id);

    // Get site if exists
    domain.DiveSite? site;
    if (row.siteId != null) {
      final siteQuery = _db.select(_db.diveSites)
        ..where((t) => t.id.equals(row.siteId!));
      final siteRow = await siteQuery.getSingleOrNull();
      if (siteRow != null) {
        site = domain.DiveSite(
          id: siteRow.id,
          name: siteRow.name,
          description: siteRow.description,
          location: siteRow.latitude != null && siteRow.longitude != null
              ? domain.GeoPoint(siteRow.latitude!, siteRow.longitude!)
              : null,
          maxDepth: siteRow.maxDepth,
          country: siteRow.country,
          region: siteRow.region,
          rating: siteRow.rating,
          notes: siteRow.notes,
        );
      }
    }

    // Get dive center if exists
    domain.DiveCenter? diveCenter;
    if (row.diveCenterId != null) {
      final centerQuery = _db.select(_db.diveCenters)
        ..where((t) => t.id.equals(row.diveCenterId!));
      final centerRow = await centerQuery.getSingleOrNull();
      if (centerRow != null) {
        diveCenter = domain.DiveCenter(
          id: centerRow.id,
          name: centerRow.name,
          location: centerRow.location,
          latitude: centerRow.latitude,
          longitude: centerRow.longitude,
          country: centerRow.country,
          phone: centerRow.phone,
          email: centerRow.email,
          website: centerRow.website,
          affiliations: centerRow.affiliations?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? [],
          rating: centerRow.rating,
          notes: centerRow.notes,
          createdAt: DateTime.fromMillisecondsSinceEpoch(centerRow.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(centerRow.updatedAt),
        );
      }
    }

    // Get tags for this dive
    final tags = await _tagRepository.getTagsForDive(row.id);

    return domain.Dive(
      id: row.id,
      diveNumber: row.diveNumber,
      dateTime: DateTime.fromMillisecondsSinceEpoch(row.diveDateTime),
      entryTime: row.entryTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.entryTime!)
          : null,
      exitTime: row.exitTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.exitTime!)
          : null,
      duration: row.duration != null ? Duration(seconds: row.duration!) : null,
      maxDepth: row.maxDepth,
      avgDepth: row.avgDepth,
      waterTemp: row.waterTemp,
      airTemp: row.airTemp,
      visibility: row.visibility != null
          ? Visibility.values.firstWhere(
              (v) => v.name == row.visibility,
              orElse: () => Visibility.unknown,
            )
          : null,
      diveTypeId: row.diveType,
      buddy: row.buddy,
      diveMaster: row.diveMaster,
      notes: row.notes,
      site: site,
      diveCenter: diveCenter,
      rating: row.rating,
      // Conditions fields
      currentDirection: row.currentDirection != null
          ? CurrentDirection.values.firstWhere(
              (c) => c.name == row.currentDirection,
              orElse: () => CurrentDirection.none,
            )
          : null,
      currentStrength: row.currentStrength != null
          ? CurrentStrength.values.firstWhere(
              (c) => c.name == row.currentStrength,
              orElse: () => CurrentStrength.none,
            )
          : null,
      swellHeight: row.swellHeight,
      entryMethod: row.entryMethod != null
          ? EntryMethod.values.firstWhere(
              (e) => e.name == row.entryMethod,
              orElse: () => EntryMethod.other,
            )
          : null,
      exitMethod: row.exitMethod != null
          ? EntryMethod.values.firstWhere(
              (e) => e.name == row.exitMethod,
              orElse: () => EntryMethod.other,
            )
          : null,
      waterType: row.waterType != null
          ? WaterType.values.firstWhere(
              (w) => w.name == row.waterType,
              orElse: () => WaterType.salt,
            )
          : null,
      // Weight system fields
      weightAmount: row.weightAmount,
      weightType: row.weightType != null
          ? WeightType.values.firstWhere(
              (w) => w.name == row.weightType,
              orElse: () => WeightType.belt,
            )
          : null,
      tanks: tankRows.map((t) => domain.DiveTank(
        id: t.id,
        name: t.tankName,
        volume: t.volume,
        workingPressure: t.workingPressure,
        startPressure: t.startPressure,
        endPressure: t.endPressure,
        gasMix: domain.GasMix(o2: t.o2Percent, he: t.hePercent),
        role: TankRole.values.firstWhere(
          (r) => r.name == t.tankRole,
          orElse: () => TankRole.backGas,
        ),
        material: t.tankMaterial != null
            ? TankMaterial.values.firstWhere(
                (m) => m.name == t.tankMaterial,
                orElse: () => TankMaterial.aluminum,
              )
            : null,
        order: t.tankOrder,
      ),).toList(),
      profile: profileRows.map((p) => domain.DiveProfilePoint(
        timestamp: p.timestamp,
        depth: p.depth,
        pressure: p.pressure,
        temperature: p.temperature,
        heartRate: p.heartRate,
      ),).toList(),
      equipment: equipmentItems,
      weights: weights,
      isFavorite: row.isFavorite,
      tags: tags,
    );
  }

  // ============================================================================
  // Favorite Operations
  // ============================================================================

  /// Toggle favorite status for a dive
  Future<void> toggleFavorite(String diveId) async {
    try {
      _log.info('Toggling favorite for dive: $diveId');
      await _db.customStatement('''
        UPDATE dives SET is_favorite = NOT is_favorite, updated_at = ?
        WHERE id = ?
      ''', [DateTime.now().millisecondsSinceEpoch, diveId],);
      _log.info('Toggled favorite for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error('Failed to toggle favorite for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Set favorite status for a dive
  Future<void> setFavorite(String diveId, bool isFavorite) async {
    try {
      _log.info('Setting favorite=$isFavorite for dive: $diveId');
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(
          isFavorite: Value(isFavorite),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      _log.info('Set favorite=$isFavorite for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error('Failed to set favorite for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get all favorite dives
  Future<List<domain.Dive>> getFavoriteDives() async {
    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.isFavorite.equals(true))
        ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

      final rows = await query.get();
      return Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error('Failed to get favorite dives', e, stackTrace);
      rethrow;
    }
  }

  /// Load weights for a dive
  Future<List<domain.DiveWeight>> _loadWeightsForDive(String diveId) async {
    try {
      final query = _db.select(_db.diveWeights)
        ..where((w) => w.diveId.equals(diveId));
      final rows = await query.get();
      return rows.map((row) => domain.DiveWeight(
        id: row.id,
        diveId: row.diveId,
        weightType: WeightType.values.firstWhere(
          (w) => w.name == row.weightType,
          orElse: () => WeightType.belt,
        ),
        amountKg: row.amountKg,
        notes: row.notes,
      ),).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to load weights for dive: $diveId', e, stackTrace);
      return [];
    }
  }

  // ============================================================================
  // Surface Interval Operations
  // ============================================================================

  /// Get the previous dive (by entry time) for surface interval calculation
  /// Returns null if this is the first dive
  Future<domain.Dive?> getPreviousDive(String diveId) async {
    try {
      // First get the current dive's entry time
      final currentDive = await getDiveById(diveId);
      if (currentDive == null) return null;

      final entryTime = currentDive.entryTime ?? currentDive.dateTime;

      // Find the most recent dive that ended before this one started
      final query = _db.select(_db.dives)
        ..where((t) => t.id.isNotValue(diveId))
        ..where((t) => t.entryTime.isSmallerThanValue(entryTime.millisecondsSinceEpoch) | 
                       (t.entryTime.isNull() & t.diveDateTime.isSmallerThanValue(entryTime.millisecondsSinceEpoch)),)
        ..orderBy([(t) => OrderingTerm.desc(t.entryTime), (t) => OrderingTerm.desc(t.diveDateTime)])
        ..limit(1);

      final rows = await query.get();
      if (rows.isEmpty) return null;

      return _mapRowToDive(rows.first);
    } catch (e, stackTrace) {
      _log.error('Failed to get previous dive for: $diveId', e, stackTrace);
      return null;
    }
  }

  /// Calculate surface interval between this dive and the previous dive
  /// Returns null if there is no previous dive
  Future<Duration?> getSurfaceInterval(String diveId) async {
    try {
      final currentDive = await getDiveById(diveId);
      if (currentDive == null) return null;

      final previousDive = await getPreviousDive(diveId);
      if (previousDive == null) return null;

      // Calculate interval: from previous dive exit to current dive entry
      final previousExitTime = previousDive.exitTime ?? 
          (previousDive.entryTime ?? previousDive.dateTime).add(previousDive.calculatedDuration ?? Duration.zero);
      final currentEntryTime = currentDive.entryTime ?? currentDive.dateTime;

      final interval = currentEntryTime.difference(previousExitTime);
      return interval.isNegative ? Duration.zero : interval;
    } catch (e, stackTrace) {
      _log.error('Failed to calculate surface interval for: $diveId', e, stackTrace);
      return null;
    }
  }

  // ============================================================================
  // Dive Numbering Operations
  // ============================================================================

  /// Get all dive numbers with gaps detected
  /// Returns a list of DiveNumberInfo including gaps
  Future<DiveNumberingInfo> getDiveNumberingInfo() async {
    try {
      final query = _db.select(_db.dives)
        ..orderBy([(t) => OrderingTerm.asc(t.entryTime), (t) => OrderingTerm.asc(t.diveDateTime)]);

      final rows = await query.get();
      
      final dives = <DiveNumberEntry>[];
      final gaps = <DiveNumberGap>[];
      
      int? lastNumber;
      for (final row in rows) {
        final entryTime = row.entryTime != null 
            ? DateTime.fromMillisecondsSinceEpoch(row.entryTime!)
            : DateTime.fromMillisecondsSinceEpoch(row.diveDateTime);
        
        dives.add(DiveNumberEntry(
          diveId: row.id,
          currentNumber: row.diveNumber,
          entryTime: entryTime,
        ),);
        
        // Check for gaps
        if (row.diveNumber != null && lastNumber != null) {
          final expected = lastNumber + 1;
          if (row.diveNumber! > expected) {
            gaps.add(DiveNumberGap(
              afterDiveId: dives.length > 1 ? dives[dives.length - 2].diveId : null,
              missingStart: expected,
              missingEnd: row.diveNumber! - 1,
            ),);
          }
        }
        lastNumber = row.diveNumber;
      }
      
      return DiveNumberingInfo(
        dives: dives,
        gaps: gaps,
        hasGaps: gaps.isNotEmpty,
        hasUnnumbered: dives.any((d) => d.currentNumber == null),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get dive numbering info', e, stackTrace);
      rethrow;
    }
  }

  /// Renumber all dives sequentially based on entry time
  /// [startFrom] - The starting dive number (default 1)
  Future<void> renumberAllDives({int startFrom = 1}) async {
    try {
      _log.info('Renumbering all dives starting from $startFrom');
      
      final query = _db.select(_db.dives)
        ..orderBy([(t) => OrderingTerm.asc(t.entryTime), (t) => OrderingTerm.asc(t.diveDateTime)]);

      final rows = await query.get();
      
      int number = startFrom;
      for (final row in rows) {
        await (_db.update(_db.dives)..where((t) => t.id.equals(row.id))).write(
          DivesCompanion(
            diveNumber: Value(number),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
        number++;
      }
      
      _log.info('Renumbered ${rows.length} dives');
    } catch (e, stackTrace) {
      _log.error('Failed to renumber dives', e, stackTrace);
      rethrow;
    }
  }

  /// Fill gaps in dive numbers without changing existing numbers
  /// This assigns numbers to dives that have null dive numbers
  Future<void> assignMissingDiveNumbers() async {
    try {
      _log.info('Assigning missing dive numbers');
      
      // Get all dives ordered by entry time
      final query = _db.select(_db.dives)
        ..orderBy([(t) => OrderingTerm.asc(t.entryTime), (t) => OrderingTerm.asc(t.diveDateTime)]);

      final rows = await query.get();
      
      // Find the highest existing number
      int maxNumber = 0;
      for (final row in rows) {
        if (row.diveNumber != null && row.diveNumber! > maxNumber) {
          maxNumber = row.diveNumber!;
        }
      }
      
      // Assign numbers to unnumbered dives
      int nextNumber = maxNumber + 1;
      for (final row in rows) {
        if (row.diveNumber == null) {
          await (_db.update(_db.dives)..where((t) => t.id.equals(row.id))).write(
            DivesCompanion(
              diveNumber: Value(nextNumber),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
          nextNumber++;
        }
      }
      
      _log.info('Assigned numbers to ${nextNumber - maxNumber - 1} dives');
    } catch (e, stackTrace) {
      _log.error('Failed to assign missing dive numbers', e, stackTrace);
      rethrow;
    }
  }
}

/// Statistics summary for dives
class DiveStatistics {
  final int totalDives;
  final int totalTimeSeconds;
  final double maxDepth;
  final double avgMaxDepth;
  final double? avgTemperature;
  final int totalSites;
  final List<MonthlyDiveCount> divesByMonth;
  final List<DepthRangeStat> depthDistribution;
  final List<TopSiteStat> topSites;

  DiveStatistics({
    required this.totalDives,
    required this.totalTimeSeconds,
    required this.maxDepth,
    required this.avgMaxDepth,
    this.avgTemperature,
    required this.totalSites,
    this.divesByMonth = const [],
    this.depthDistribution = const [],
    this.topSites = const [],
  });

  Duration get totalTime => Duration(seconds: totalTimeSeconds);

  String get totalTimeFormatted {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

/// Monthly dive count for bar chart
class MonthlyDiveCount {
  final int year;
  final int month;
  final int count;

  MonthlyDiveCount({required this.year, required this.month, required this.count});

  String get label {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String get fullLabel => '$label $year';
}

/// Depth range statistics for distribution chart
class DepthRangeStat {
  final String label;
  final int minDepth;
  final int maxDepth;
  final int count;

  DepthRangeStat({
    required this.label,
    required this.minDepth,
    required this.maxDepth,
    required this.count,
  });
}

/// Top dive site statistics
class TopSiteStat {
  final String siteName;
  final int diveCount;

  TopSiteStat({required this.siteName, required this.diveCount});
}

/// Dive records (superlatives)
class DiveRecords {
  final DiveRecord? deepestDive;
  final DiveRecord? longestDive;
  final DiveRecord? coldestDive;
  final DiveRecord? warmestDive;
  final DiveRecord? firstDive;
  final DiveRecord? lastDive;
  final DiveRecord? shallowestDive;

  DiveRecords({
    this.deepestDive,
    this.longestDive,
    this.coldestDive,
    this.warmestDive,
    this.firstDive,
    this.lastDive,
    this.shallowestDive,
  });
}

/// A single dive record entry
class DiveRecord {
  final String diveId;
  final int? diveNumber;
  final String? siteName;
  final DateTime dateTime;
  final double? maxDepth;
  final Duration? duration;
  final double? waterTemp;

  DiveRecord({
    required this.diveId,
    this.diveNumber,
    this.siteName,
    required this.dateTime,
    this.maxDepth,
    this.duration,
    this.waterTemp,
  });
}

/// Information about dive numbering, including gaps
class DiveNumberingInfo {
  final List<DiveNumberEntry> dives;
  final List<DiveNumberGap> gaps;
  final bool hasGaps;
  final bool hasUnnumbered;

  DiveNumberingInfo({
    required this.dives,
    required this.gaps,
    required this.hasGaps,
    required this.hasUnnumbered,
  });

  /// Total number of dives
  int get totalDives => dives.length;

  /// Number of numbered dives
  int get numberedDives => dives.where((d) => d.currentNumber != null).length;

  /// Number of unnumbered dives
  int get unnumberedDives => dives.where((d) => d.currentNumber == null).length;
}

/// Entry for dive number info
class DiveNumberEntry {
  final String diveId;
  final int? currentNumber;
  final DateTime entryTime;

  DiveNumberEntry({
    required this.diveId,
    this.currentNumber,
    required this.entryTime,
  });
}

/// A gap in dive numbers
class DiveNumberGap {
  final String? afterDiveId;
  final int missingStart;
  final int missingEnd;

  DiveNumberGap({
    this.afterDiveId,
    required this.missingStart,
    required this.missingEnd,
  });

  /// Number of missing dive numbers in this gap
  int get count => missingEnd - missingStart + 1;

  /// Human-readable description of the gap
  String get description {
    if (missingStart == missingEnd) {
      return 'Missing dive #$missingStart';
    }
    return 'Missing dives #$missingStart-$missingEnd';
  }
}
