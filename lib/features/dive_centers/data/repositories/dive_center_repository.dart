import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart'
    as domain;
import 'package:submersion/features/dive_log/data/repositories/dive_parent_links.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

class DiveCenterRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveCenterRepository);

  /// Emits whenever the `dive_centers` table changes so list providers can
  /// refresh after a sync or any other write.
  Stream<void> watchDiveCentersChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diveCenters));

  /// Get all dive centers
  Future<List<domain.DiveCenter>> getAllDiveCenters({String? diverId}) async {
    try {
      final query = _db.select(_db.diveCenters)
        ..orderBy([(t) => OrderingTerm.asc(t.name.collate(Collate.noCase))]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return sortedByText(
        rows,
        (r) => r.name,
      ).map(_mapRowToDiveCenter).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all dive centers',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a dive center by ID
  Future<domain.DiveCenter?> getDiveCenterById(String id) async {
    try {
      final query = _db.select(_db.diveCenters)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToDiveCenter(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive center by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Search dive centers by name, city, or country
  Future<List<domain.DiveCenter>> searchDiveCenters(
    String query, {
    String? diverId,
  }) async {
    final searchTerm = '%${query.toLowerCase()}%';
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final variables = [
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      if (diverId != null) Variable.withString(diverId),
    ];

    final results = await _db.customSelect('''
      SELECT * FROM dive_centers
      WHERE (unicode_lower(name) LIKE ?
         OR unicode_lower(city) LIKE ?
         OR unicode_lower(country) LIKE ?)
      $diverFilter
      ORDER BY name COLLATE NOCASE ASC
    ''', variables: variables).get();

    return sortedByText(
      results,
      (r) => r.data['name'] as String,
    ).map(_mapCustomRowToDiveCenter).toList();
  }

  /// Get dive centers by country
  Future<List<domain.DiveCenter>> getDiveCentersByCountry(
    String country, {
    String? diverId,
  }) async {
    final query = _db.select(_db.diveCenters)
      ..where((t) => t.country.equals(country))
      ..orderBy([(t) => OrderingTerm.asc(t.name.collate(Collate.noCase))]);

    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId));
    }

    final rows = await query.get();
    return sortedByText(rows, (r) => r.name).map(_mapRowToDiveCenter).toList();
  }

  /// Get dive centers with coordinates (for map view)
  Future<List<domain.DiveCenter>> getDiveCentersWithCoordinates({
    String? diverId,
  }) async {
    final query = _db.select(_db.diveCenters)
      ..where((t) => t.latitude.isNotNull() & t.longitude.isNotNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name.collate(Collate.noCase))]);

    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId));
    }

    final rows = await query.get();
    return sortedByText(rows, (r) => r.name).map(_mapRowToDiveCenter).toList();
  }

  /// Create a new dive center
  Future<domain.DiveCenter> createDiveCenter(domain.DiveCenter center) async {
    try {
      _log.info('Creating dive center: ${center.name}');
      final id = center.id.isEmpty ? _uuid.v4() : center.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.diveCenters)
          .insert(
            DiveCentersCompanion(
              id: Value(id),
              diverId: Value(center.diverId),
              name: Value(center.name),
              street: Value(center.street),
              city: Value(center.city),
              stateProvince: Value(center.stateProvince),
              postalCode: Value(center.postalCode),
              latitude: Value(center.latitude),
              longitude: Value(center.longitude),
              country: Value(center.country),
              phone: Value(center.phone),
              email: Value(center.email),
              website: Value(center.website),
              affiliations: Value(center.affiliations.join(',')),
              rating: Value(center.rating),
              notes: Value(center.notes),
              fillOpensAt: Value(center.fillOpensAt),
              fillClosesAt: Value(center.fillClosesAt),
              isPermanentlyClosed: Value(center.isPermanentlyClosed),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'diveCenters',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created dive center with id: $id');
      return center.copyWith(id: id);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create dive center: ${center.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The diver's dive center called [name] (ignoring case), else an unowned
  /// one of that name claimed for the diver, else a new one for the diver.
  /// For an import that knows a center only by name (issue #3491). Centers
  /// are diver-scoped, so another diver's namesake is never linked.
  Future<domain.DiveCenter> findOrCreateByName(
    String name, {
    required String diverId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Dive center name cannot be empty');
    }
    final rows = await _db
        .customSelect(
          'SELECT id FROM dive_centers '
          'WHERE unicode_lower(TRIM(name)) = unicode_lower(?) '
          'AND (diver_id = ? OR diver_id IS NULL) '
          'ORDER BY diver_id IS NULL, rowid LIMIT 1',
          variables: [
            Variable.withString(trimmed),
            Variable.withString(diverId),
          ],
        )
        .get();
    if (rows.isNotEmpty) {
      final found = await getDiveCenterById(rows.first.read<String>('id'));
      // The row is re-checked here: another import may have claimed it
      // since the lookup, and then it is no longer this diver's to link.
      if (found != null) {
        if (found.diverId == diverId) return found;
        if (found.diverId == null && await _claimForDiver(found.id, diverId)) {
          return found.copyWith(diverId: diverId);
        }
      }
    }
    final now = DateTime.now();
    return createDiveCenter(
      domain.DiveCenter(
        id: '',
        diverId: diverId,
        name: trimmed,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Gives an unowned center to [diverId], returning false when it was
  /// claimed by someone else first. [updateDiveCenter] leaves the owner
  /// alone, so the claim is its own guarded write.
  Future<bool> _claimForDiver(String centerId, String diverId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = await _db.customUpdate(
      'UPDATE dive_centers SET diver_id = ?, updated_at = ? '
      'WHERE id = ? AND diver_id IS NULL',
      variables: [
        Variable.withString(diverId),
        Variable.withInt(now),
        Variable.withString(centerId),
      ],
      updates: {_db.diveCenters},
    );
    if (changed == 0) return false;
    await _syncRepository.markRecordPending(
      entityType: 'diveCenters',
      recordId: centerId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return true;
  }

  /// Update an existing dive center
  Future<void> updateDiveCenter(domain.DiveCenter center) async {
    try {
      _log.info('Updating dive center: ${center.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.diveCenters,
      )..where((t) => t.id.equals(center.id))).write(
        DiveCentersCompanion(
          name: Value(center.name),
          street: Value(center.street),
          city: Value(center.city),
          stateProvince: Value(center.stateProvince),
          postalCode: Value(center.postalCode),
          latitude: Value(center.latitude),
          longitude: Value(center.longitude),
          country: Value(center.country),
          phone: Value(center.phone),
          email: Value(center.email),
          website: Value(center.website),
          affiliations: Value(center.affiliations.join(',')),
          rating: Value(center.rating),
          notes: Value(center.notes),
          fillOpensAt: Value(center.fillOpensAt),
          fillClosesAt: Value(center.fillClosesAt),
          isPermanentlyClosed: Value(center.isPermanentlyClosed),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveCenters',
        recordId: center.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated dive center: ${center.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update dive center: ${center.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a dive center. The dives logged with it survive with the center
  /// cleared: `dives.dive_center_id` has no ON DELETE action, so a dive still
  /// pointing at the center would fail the delete (issue #1952). Its rental
  /// gear notes cascade, and each is tombstoned by hand: SQLite cascades
  /// write no deletion-log rows, so a peer would otherwise resurrect them
  /// (issue #2075). One transaction, so a failed delete leaves the dives
  /// linked and the notes in place.
  Future<void> deleteDiveCenter(String id) async {
    try {
      _log.info('Deleting dive center: $id');
      await _db.transaction(() async {
        final notes = await (_db.select(
          _db.diveCenterGearNotes,
        )..where((t) => t.diveCenterId.equals(id))).get();
        await clearDiveCenterLinks(_db, _syncRepository, [
          id,
        ], now: DateTime.now().millisecondsSinceEpoch);
        // Its documents go with it, tombstoned (issue #2613).
        await DocumentRepository().deleteForOwner(
          DocumentOwnerKind.diveCenter,
          id,
        );
        await (_db.delete(_db.diveCenters)..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(
          entityType: 'diveCenters',
          recordId: id,
        );
        for (final note in notes) {
          await _syncRepository.logDeletion(
            entityType: 'diveCenterGearNotes',
            recordId: note.id,
          );
        }
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted dive center: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete dive center: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// How many dives a delete of [centerIds] would leave without a center.
  /// stats-scope-exempt: the delete clears every dive, excluded and planned
  /// ones included, so the confirmation counts them all.
  Future<int> getLinkedDiveCount(List<String> centerIds) async {
    if (centerIds.isEmpty) return 0;
    final count = _db.dives.id.count();
    final query = _db.selectOnly(_db.dives)
      ..addColumns([count])
      ..where(_db.dives.diveCenterId.isIn(centerIds));
    return await query.map((row) => row.read(count)).getSingle() ?? 0;
  }

  /// Get dive count for a dive center
  Future<int> getDiveCountForCenter(String centerId) async {
    final result = await _db
        .customSelect(
          '''
      SELECT COUNT(*) as count
      FROM dives
      WHERE dive_center_id = ?${DiveStatsScope.and(alias: 'dives')}
    ''',
          variables: [Variable.withString(centerId)],
        )
        .getSingle();

    return result.data['count'] as int? ?? 0;
  }

  /// The newest real dive logged with [centerId], skipping planned dives
  /// and [excludingDiveId] (the dive being edited), for the "last time
  /// here" card (issue #2075). Null when the diver has no other dive there.
  /// stats-scope-exempt: a displayed lookup, not a statistic; a dive the
  /// diver excluded from their numbers still tells them what they wore.
  Future<String?> latestDiveIdAtCenter(
    String centerId, {
    String? excludingDiveId,
  }) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT id FROM dives
      WHERE dive_center_id = ?
        AND is_planned = 0
        AND (? IS NULL OR id <> ?)
      ORDER BY dive_date_time DESC, id DESC
      LIMIT 1
    ''',
          variables: [
            Variable.withString(centerId),
            Variable<String>(excludingDiveId),
            Variable<String>(excludingDiveId),
          ],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String>('id');
  }

  /// Get all unique countries
  Future<List<String>> getCountries({String? diverId}) async {
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final variables = diverId != null
        ? [Variable.withString(diverId)]
        : <Variable<Object>>[];

    final results = await _db.customSelect('''
      SELECT DISTINCT country FROM dive_centers
      WHERE country IS NOT NULL AND country != ''
      $diverFilter
      ORDER BY country ASC
    ''', variables: variables).get();

    return results.map((row) => row.data['country'] as String).toList();
  }

  domain.DiveCenter _mapRowToDiveCenter(DiveCenter row) {
    return domain.DiveCenter(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      street: row.street,
      city: row.city,
      stateProvince: row.stateProvince,
      postalCode: row.postalCode,
      latitude: row.latitude,
      longitude: row.longitude,
      country: row.country,
      phone: row.phone,
      email: row.email,
      website: row.website,
      affiliations: _parseAffiliations(row.affiliations),
      rating: row.rating,
      notes: row.notes,
      fillOpensAt: row.fillOpensAt,
      fillClosesAt: row.fillClosesAt,
      isPermanentlyClosed: row.isPermanentlyClosed,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  domain.DiveCenter _mapCustomRowToDiveCenter(QueryRow row) {
    return domain.DiveCenter(
      id: row.data['id'] as String,
      name: row.data['name'] as String,
      street: row.data['street'] as String?,
      city: row.data['city'] as String?,
      stateProvince: row.data['state_province'] as String?,
      postalCode: row.data['postal_code'] as String?,
      latitude: (row.data['latitude'] as num?)?.toDouble(),
      longitude: (row.data['longitude'] as num?)?.toDouble(),
      country: row.data['country'] as String?,
      phone: row.data['phone'] as String?,
      email: row.data['email'] as String?,
      website: row.data['website'] as String?,
      affiliations: _parseAffiliations(row.data['affiliations'] as String?),
      rating: (row.data['rating'] as num?)?.toDouble(),
      notes: (row.data['notes'] as String?) ?? '',
      fillOpensAt: row.data['fill_opens_at'] as int?,
      fillClosesAt: row.data['fill_closes_at'] as int?,
      isPermanentlyClosed:
          (row.data['is_permanently_closed'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.data['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.data['updated_at'] as int,
      ),
    );
  }

  List<String> _parseAffiliations(String? affiliationsStr) {
    if (affiliationsStr == null || affiliationsStr.isEmpty) {
      return [];
    }
    return affiliationsStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
