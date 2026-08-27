import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart'
    as domain;

class CertificationRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(CertificationRepository);

  /// Emits whenever the `certifications` table changes so list providers can
  /// refresh after a sync or any other write.
  Stream<void> watchCertificationsChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.certifications));

  /// Get all certifications ordered by issue date (newest first)
  Future<List<domain.Certification>> getAllCertifications({
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.certifications)
        ..orderBy([
          (t) => OrderingTerm.desc(t.issueDate),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToCertification).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all certifications',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get certification by ID
  Future<domain.Certification?> getCertificationById(String id) async {
    try {
      final query = _db.select(_db.certifications)
        ..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToCertification(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get certification by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Search certifications by name or agency
  Future<List<domain.Certification>> searchCertifications(
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
      SELECT * FROM certifications
      WHERE (LOWER(name) LIKE ?
         OR LOWER(agency) LIKE ?
         OR LOWER(card_number) LIKE ?)
      $diverFilter
      ORDER BY issue_date DESC, name ASC
    ''', variables: variables).get();

    return results.map(_mapQueryRowToCertification).toList();
  }

  /// All certifications owned by a buddy (newest issue date first). Issue #553.
  Future<List<domain.Certification>> getCertificationsByBuddy(
    String buddyId,
  ) async {
    final query = _db.select(_db.certifications)
      ..where((t) => t.buddyId.equals(buddyId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.issueDate),
        (t) => OrderingTerm.asc(t.name),
      ]);
    final rows = await query.get();
    return rows.map(_mapRowToCertification).toList();
  }

  /// Certifications for many buddies at once, grouped by buddyId. Single query
  /// (no N+1) so buddy-list hydration stays O(1). Issue #553.
  Future<Map<String, List<domain.Certification>>> getCertificationsForBuddies(
    List<String> buddyIds,
  ) async {
    if (buddyIds.isEmpty) return {};
    final query = _db.select(_db.certifications)
      ..where((t) => t.buddyId.isIn(buddyIds));
    final rows = await query.get();
    final out = <String, List<domain.Certification>>{};
    for (final row in rows) {
      final cert = _mapRowToCertification(row);
      (out[cert.buddyId!] ??= []).add(cert);
    }
    return out;
  }

  /// Replace a buddy's certification set with [desired]: insert new (empty id),
  /// update existing, and delete+tombstone existing rows not in [desired].
  /// Backs the buddy edit form's stage-then-commit-on-save flow (issue #553).
  Future<void> replaceBuddyCertifications(
    String buddyId,
    List<domain.Certification> desired,
  ) async {
    // Atomic (issue #553 review): a mid-way interruption must not leave a
    // partially-updated cert set. Mirrors the transaction pattern in
    // BuddyMergeRepository. The create/update/delete calls run with
    // notify:false so a single notifyLocalChange() fires after commit instead
    // of one per row mid-transaction (which would churn UI / let observers read
    // a half-updated set). markRecordPending/logDeletion still run inside the
    // transaction -- only the observable event is deferred.
    var mutated = false;
    await _db.transaction(() async {
      final existing = await getCertificationsByBuddy(buddyId);
      final existingById = {for (final c in existing) c.id: c};
      final keptIds = <String>{};
      for (final cert in desired) {
        final owned = cert.copyWith(buddyId: buddyId);
        final current = existingById[owned.id];
        if (owned.id.isEmpty || current == null) {
          final created = await createCertification(owned, notify: false);
          keptIds.add(created.id);
          mutated = true;
        } else {
          // Only write when something actually changed, so saving a buddy
          // (e.g. editing only name/notes) doesn't bump every cert's
          // updatedAt and sync state (issue #553 review).
          if (owned != current) {
            await updateCertification(owned, notify: false);
            mutated = true;
          }
          keptIds.add(owned.id);
        }
      }
      for (final c in existing) {
        if (!keptIds.contains(c.id)) {
          await deleteCertification(c.id, notify: false);
          mutated = true;
        }
      }
    });
    if (mutated) SyncEventBus.notifyLocalChange();
  }

  /// Create a new certification
  Future<domain.Certification> createCertification(
    domain.Certification cert, {
    bool notify = true,
  }) async {
    try {
      _log.info('Creating certification: ${cert.name}');
      final id = cert.id.isEmpty ? _uuid.v4() : cert.id;
      final now = DateTime.now();

      // issue #553: a certification belongs to a diver or a buddy, never
      // both. (Ownerless certs remain valid: legacy rows and the
      // no-validated-diver fallback both create them.)
      if (cert.diverId != null && cert.buddyId != null) {
        throw ArgumentError(
          'Certification cannot belong to both a diver and a buddy',
        );
      }

      await _db
          .into(_db.certifications)
          .insert(
            CertificationsCompanion(
              id: Value(id),
              diverId: Value(cert.diverId),
              buddyId: Value(cert.buddyId),
              name: Value(cert.name),
              agency: Value(cert.agency.name),
              level: Value(cert.level?.name),
              cardNumber: Value(cert.cardNumber),
              issueDate: Value(cert.issueDate?.millisecondsSinceEpoch),
              expiryDate: Value(cert.expiryDate?.millisecondsSinceEpoch),
              instructorName: Value(cert.instructorName),
              instructorNumber: Value(cert.instructorNumber),
              instructorId: Value(cert.instructorId),
              photoFront: Value(cert.photoFront),
              photoBack: Value(cert.photoBack),
              notes: Value(cert.notes),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'certifications',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      if (notify) SyncEventBus.notifyLocalChange();

      _log.info('Created certification with id: $id');
      return cert.copyWith(id: id, createdAt: now, updatedAt: now);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create certification: ${cert.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing certification
  Future<void> updateCertification(
    domain.Certification cert, {
    bool notify = true,
  }) async {
    try {
      _log.info('Updating certification: ${cert.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.certifications,
      )..where((t) => t.id.equals(cert.id))).write(
        CertificationsCompanion(
          name: Value(cert.name),
          agency: Value(cert.agency.name),
          level: Value(cert.level?.name),
          cardNumber: Value(cert.cardNumber),
          issueDate: Value(cert.issueDate?.millisecondsSinceEpoch),
          expiryDate: Value(cert.expiryDate?.millisecondsSinceEpoch),
          instructorName: Value(cert.instructorName),
          instructorNumber: Value(cert.instructorNumber),
          instructorId: Value(cert.instructorId),
          photoFront: Value(cert.photoFront),
          photoBack: Value(cert.photoBack),
          notes: Value(cert.notes),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'certifications',
        recordId: cert.id,
        localUpdatedAt: now,
      );
      if (notify) SyncEventBus.notifyLocalChange();
      _log.info('Updated certification: ${cert.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update certification: ${cert.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a certification
  Future<void> deleteCertification(String id, {bool notify = true}) async {
    try {
      _log.info('Deleting certification: $id');
      await (_db.delete(
        _db.certifications,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'certifications',
        recordId: id,
      );
      if (notify) SyncEventBus.notifyLocalChange();
      _log.info('Deleted certification: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete certification: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get certifications expiring within days
  Future<List<domain.Certification>> getExpiringCertifications(
    int withinDays, {
    String? diverId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final threshold = DateTime.now()
        .add(Duration(days: withinDays))
        .millisecondsSinceEpoch;

    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final variables = [
      Variable.withInt(now),
      Variable.withInt(threshold),
      if (diverId != null) Variable.withString(diverId),
    ];

    final results = await _db.customSelect('''
      SELECT * FROM certifications
      WHERE expiry_date IS NOT NULL
        AND expiry_date > ?
        AND expiry_date <= ?
        $diverFilter
      ORDER BY expiry_date ASC
    ''', variables: variables).get();

    return results.map(_mapQueryRowToCertification).toList();
  }

  /// Get expired certifications
  Future<List<domain.Certification>> getExpiredCertifications({
    String? diverId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final variables = [
      Variable.withInt(now),
      if (diverId != null) Variable.withString(diverId),
    ];

    final results = await _db.customSelect('''
      SELECT * FROM certifications
      WHERE expiry_date IS NOT NULL
        AND expiry_date <= ?
        $diverFilter
      ORDER BY expiry_date DESC
    ''', variables: variables).get();

    return results.map(_mapQueryRowToCertification).toList();
  }

  /// Get certifications by agency
  Future<List<domain.Certification>> getCertificationsByAgency(
    CertificationAgency agency,
  ) async {
    final query = _db.select(_db.certifications)
      ..where((t) => t.agency.equals(agency.name))
      ..orderBy([(t) => OrderingTerm.desc(t.issueDate)]);

    final rows = await query.get();
    return rows.map(_mapRowToCertification).toList();
  }

  /// Maps a raw certifications row (from a customSelect query) to a domain
  /// entity. Kept in step with [_mapRowToCertification] -- notably it hydrates
  /// buddyId (issue #553), which the per-query hand-mapping used to drop.
  domain.Certification _mapQueryRowToCertification(QueryRow row) {
    return domain.Certification(
      id: row.data['id'] as String,
      diverId: row.data['diver_id'] as String?,
      buddyId: row.data['buddy_id'] as String?,
      name: row.data['name'] as String,
      agency: _parseCertificationAgency(row.data['agency'] as String),
      level: _parseCertificationLevel(row.data['level'] as String?),
      cardNumber: row.data['card_number'] as String?,
      issueDate: _parseDateTime(row.data['issue_date'] as int?),
      expiryDate: _parseDateTime(row.data['expiry_date'] as int?),
      instructorName: row.data['instructor_name'] as String?,
      instructorNumber: row.data['instructor_number'] as String?,
      instructorId: row.data['instructor_id'] as String?,
      photoFront: row.data['photo_front'] as Uint8List?,
      photoBack: row.data['photo_back'] as Uint8List?,
      notes: (row.data['notes'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.data['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.data['updated_at'] as int,
      ),
    );
  }

  domain.Certification _mapRowToCertification(Certification row) {
    return domain.Certification(
      id: row.id,
      diverId: row.diverId,
      buddyId: row.buddyId,
      name: row.name,
      agency: _parseCertificationAgency(row.agency),
      level: _parseCertificationLevel(row.level),
      cardNumber: row.cardNumber,
      issueDate: _parseDateTime(row.issueDate),
      expiryDate: _parseDateTime(row.expiryDate),
      instructorName: row.instructorName,
      instructorNumber: row.instructorNumber,
      instructorId: row.instructorId,
      photoFront: row.photoFront,
      photoBack: row.photoBack,
      notes: row.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  DateTime? _parseDateTime(int? timestamp) {
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  CertificationAgency _parseCertificationAgency(String value) {
    return CertificationAgency.values.firstWhere(
      (a) => a.name == value,
      orElse: () => CertificationAgency.other,
    );
  }

  CertificationLevel? _parseCertificationLevel(String? value) {
    if (value == null) return null;
    return CertificationLevel.values.firstWhere(
      (l) => l.name == value,
      orElse: () => CertificationLevel.other,
    );
  }
}
