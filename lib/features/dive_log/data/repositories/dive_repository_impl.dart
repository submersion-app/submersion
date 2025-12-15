import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../domain/entities/dive.dart' as domain;
import '../../../dive_centers/domain/entities/dive_center.dart' as domain;
import '../../../dive_sites/domain/entities/dive_site.dart' as domain;
import '../../../equipment/domain/entities/equipment_item.dart';

class DiveRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();

  // ============================================================================
  // CRUD Operations
  // ============================================================================

  /// Get all dives, ordered by date (newest first)
  Future<List<domain.Dive>> getAllDives() async {
    final query = _db.select(_db.dives)
      ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

    final rows = await query.get();
    return Future.wait(rows.map(_mapRowToDive));
  }

  /// Get a single dive by ID
  Future<domain.Dive?> getDiveById(String id) async {
    final query = _db.select(_db.dives)
      ..where((t) => t.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    return _mapRowToDive(row);
  }

  /// Create a new dive
  Future<domain.Dive> createDive(domain.Dive dive) async {
    final id = dive.id.isEmpty ? _uuid.v4() : dive.id;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.dives).insert(DivesCompanion(
      id: Value(id),
      diveNumber: Value(dive.diveNumber),
      diveDateTime: Value(dive.dateTime.millisecondsSinceEpoch),
      duration: Value(dive.duration?.inSeconds),
      maxDepth: Value(dive.maxDepth),
      avgDepth: Value(dive.avgDepth),
      waterTemp: Value(dive.waterTemp),
      airTemp: Value(dive.airTemp),
      visibility: Value(dive.visibility?.name),
      diveType: Value(dive.diveType.name),
      buddy: Value(dive.buddy),
      diveMaster: Value(dive.diveMaster),
      notes: Value(dive.notes),
      siteId: Value(dive.site?.id),
      diveCenterId: Value(dive.diveCenter?.id),
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
      weightBeltUsed: Value(dive.weightBeltUsed),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    // Insert tanks
    for (final tank in dive.tanks) {
      await _db.into(_db.diveTanks).insert(DiveTanksCompanion(
        id: Value(_uuid.v4()),
        diveId: Value(id),
        volume: Value(tank.volume),
        startPressure: Value(tank.startPressure),
        endPressure: Value(tank.endPressure),
        o2Percent: Value(tank.gasMix.o2),
        hePercent: Value(tank.gasMix.he),
        tankOrder: Value(tank.order),
      ));
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
      ));
    }

    // Insert equipment associations
    for (final item in dive.equipment) {
      await _db.into(_db.diveEquipment).insert(DiveEquipmentCompanion(
        diveId: Value(id),
        equipmentId: Value(item.id),
      ));
    }

    return dive.copyWith(id: id);
  }

  /// Update an existing dive
  Future<void> updateDive(domain.Dive dive) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (_db.update(_db.dives)..where((t) => t.id.equals(dive.id))).write(
      DivesCompanion(
        diveNumber: Value(dive.diveNumber),
        diveDateTime: Value(dive.dateTime.millisecondsSinceEpoch),
        duration: Value(dive.duration?.inSeconds),
        maxDepth: Value(dive.maxDepth),
        avgDepth: Value(dive.avgDepth),
        waterTemp: Value(dive.waterTemp),
        airTemp: Value(dive.airTemp),
        visibility: Value(dive.visibility?.name),
        diveType: Value(dive.diveType.name),
        buddy: Value(dive.buddy),
        diveMaster: Value(dive.diveMaster),
        notes: Value(dive.notes),
        siteId: Value(dive.site?.id),
        diveCenterId: Value(dive.diveCenter?.id),
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
        weightBeltUsed: Value(dive.weightBeltUsed),
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
        startPressure: Value(tank.startPressure),
        endPressure: Value(tank.endPressure),
        o2Percent: Value(tank.gasMix.o2),
        hePercent: Value(tank.gasMix.he),
        tankOrder: Value(tank.order),
      ));
    }

    // Update equipment: delete and re-insert
    await (_db.delete(_db.diveEquipment)..where((t) => t.diveId.equals(dive.id))).go();
    for (final item in dive.equipment) {
      await _db.into(_db.diveEquipment).insert(DiveEquipmentCompanion(
        diveId: Value(dive.id),
        equipmentId: Value(item.id),
      ));
    }
  }

  /// Delete a dive
  Future<void> deleteDive(String id) async {
    await (_db.delete(_db.dives)..where((t) => t.id.equals(id))).go();
  }

  // ============================================================================
  // Query Operations
  // ============================================================================

  /// Get dives for a specific site
  Future<List<domain.Dive>> getDivesForSite(String siteId) async {
    final query = _db.select(_db.dives)
      ..where((t) => t.siteId.equals(siteId))
      ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

    final rows = await query.get();
    return Future.wait(rows.map(_mapRowToDive));
  }

  /// Get dives within a date range
  Future<List<domain.Dive>> getDivesInRange(DateTime start, DateTime end) async {
    final query = _db.select(_db.dives)
      ..where((t) => t.diveDateTime.isBiggerOrEqualValue(start.millisecondsSinceEpoch))
      ..where((t) => t.diveDateTime.isSmallerOrEqualValue(end.millisecondsSinceEpoch))
      ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

    final rows = await query.get();
    return Future.wait(rows.map(_mapRowToDive));
  }

  /// Get the next dive number
  Future<int> getNextDiveNumber() async {
    final result = await _db.customSelect(
      'SELECT MAX(dive_number) as max_num FROM dives',
    ).getSingle();

    final maxNum = result.data['max_num'] as int?;
    return (maxNum ?? 0) + 1;
  }

  /// Search dives by notes or buddy name
  Future<List<domain.Dive>> searchDives(String query) async {
    final searchQuery = _db.select(_db.dives)
      ..where((t) =>
          t.notes.contains(query) |
          t.buddy.contains(query) |
          t.diveMaster.contains(query))
      ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

    final rows = await searchQuery.get();
    return Future.wait(rows.map(_mapRowToDive));
  }

  // ============================================================================
  // Statistics
  // ============================================================================

  Future<DiveStatistics> getStatistics() async {
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
    )).toList();

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
    )).toList();

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
  }

  // ============================================================================
  // Mapping Helpers
  // ============================================================================

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

    return domain.Dive(
      id: row.id,
      diveNumber: row.diveNumber,
      dateTime: DateTime.fromMillisecondsSinceEpoch(row.diveDateTime),
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
      diveType: DiveType.values.firstWhere(
        (t) => t.name == row.diveType,
        orElse: () => DiveType.recreational,
      ),
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
      weightBeltUsed: row.weightBeltUsed,
      tanks: tankRows.map((t) => domain.DiveTank(
        id: t.id,
        volume: t.volume,
        startPressure: t.startPressure,
        endPressure: t.endPressure,
        gasMix: domain.GasMix(o2: t.o2Percent, he: t.hePercent),
        order: t.tankOrder,
      )).toList(),
      profile: profileRows.map((p) => domain.DiveProfilePoint(
        timestamp: p.timestamp,
        depth: p.depth,
        pressure: p.pressure,
        temperature: p.temperature,
        heartRate: p.heartRate,
      )).toList(),
      equipment: equipmentItems,
    );
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
