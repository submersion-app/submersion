import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/entities/certification.dart' as domain;

class CertificationRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();

  /// Get all certifications ordered by issue date (newest first)
  Future<List<domain.Certification>> getAllCertifications() async {
    final query = _db.select(_db.certifications)
      ..orderBy([
        (t) => OrderingTerm.desc(t.issueDate),
        (t) => OrderingTerm.asc(t.name),
      ]);

    final rows = await query.get();
    return rows.map(_mapRowToCertification).toList();
  }

  /// Get certification by ID
  Future<domain.Certification?> getCertificationById(String id) async {
    final query = _db.select(_db.certifications)
      ..where((t) => t.id.equals(id));

    final row = await query.getSingleOrNull();
    return row != null ? _mapRowToCertification(row) : null;
  }

  /// Search certifications by name or agency
  Future<List<domain.Certification>> searchCertifications(String query) async {
    final searchTerm = '%${query.toLowerCase()}%';

    final results = await _db.customSelect('''
      SELECT * FROM certifications
      WHERE LOWER(name) LIKE ?
         OR LOWER(agency) LIKE ?
         OR LOWER(card_number) LIKE ?
      ORDER BY issue_date DESC, name ASC
    ''', variables: [
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
    ]).get();

    return results.map((row) {
      return domain.Certification(
        id: row.data['id'] as String,
        name: row.data['name'] as String,
        agency: _parseCertificationAgency(row.data['agency'] as String),
        level: _parseCertificationLevel(row.data['level'] as String?),
        cardNumber: row.data['card_number'] as String?,
        issueDate: _parseDateTime(row.data['issue_date'] as int?),
        expiryDate: _parseDateTime(row.data['expiry_date'] as int?),
        instructorName: row.data['instructor_name'] as String?,
        instructorNumber: row.data['instructor_number'] as String?,
        photoFrontPath: row.data['photo_front_path'] as String?,
        photoBackPath: row.data['photo_back_path'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
      );
    }).toList();
  }

  /// Create a new certification
  Future<domain.Certification> createCertification(
      domain.Certification cert) async {
    final id = cert.id.isEmpty ? _uuid.v4() : cert.id;
    final now = DateTime.now();

    await _db.into(_db.certifications).insert(CertificationsCompanion(
          id: Value(id),
          name: Value(cert.name),
          agency: Value(cert.agency.name),
          level: Value(cert.level?.name),
          cardNumber: Value(cert.cardNumber),
          issueDate: Value(cert.issueDate?.millisecondsSinceEpoch),
          expiryDate: Value(cert.expiryDate?.millisecondsSinceEpoch),
          instructorName: Value(cert.instructorName),
          instructorNumber: Value(cert.instructorNumber),
          photoFrontPath: Value(cert.photoFrontPath),
          photoBackPath: Value(cert.photoBackPath),
          notes: Value(cert.notes),
          createdAt: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ));

    return cert.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  /// Update an existing certification
  Future<void> updateCertification(domain.Certification cert) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (_db.update(_db.certifications)..where((t) => t.id.equals(cert.id)))
        .write(
      CertificationsCompanion(
        name: Value(cert.name),
        agency: Value(cert.agency.name),
        level: Value(cert.level?.name),
        cardNumber: Value(cert.cardNumber),
        issueDate: Value(cert.issueDate?.millisecondsSinceEpoch),
        expiryDate: Value(cert.expiryDate?.millisecondsSinceEpoch),
        instructorName: Value(cert.instructorName),
        instructorNumber: Value(cert.instructorNumber),
        photoFrontPath: Value(cert.photoFrontPath),
        photoBackPath: Value(cert.photoBackPath),
        notes: Value(cert.notes),
        updatedAt: Value(now),
      ),
    );
  }

  /// Delete a certification
  Future<void> deleteCertification(String id) async {
    await (_db.delete(_db.certifications)..where((t) => t.id.equals(id))).go();
  }

  /// Get certifications expiring within days
  Future<List<domain.Certification>> getExpiringCertifications(
      int withinDays) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final threshold =
        DateTime.now().add(Duration(days: withinDays)).millisecondsSinceEpoch;

    final results = await _db.customSelect('''
      SELECT * FROM certifications
      WHERE expiry_date IS NOT NULL
        AND expiry_date > ?
        AND expiry_date <= ?
      ORDER BY expiry_date ASC
    ''', variables: [
      Variable.withInt(now),
      Variable.withInt(threshold),
    ]).get();

    return results.map((row) {
      return domain.Certification(
        id: row.data['id'] as String,
        name: row.data['name'] as String,
        agency: _parseCertificationAgency(row.data['agency'] as String),
        level: _parseCertificationLevel(row.data['level'] as String?),
        cardNumber: row.data['card_number'] as String?,
        issueDate: _parseDateTime(row.data['issue_date'] as int?),
        expiryDate: _parseDateTime(row.data['expiry_date'] as int?),
        instructorName: row.data['instructor_name'] as String?,
        instructorNumber: row.data['instructor_number'] as String?,
        photoFrontPath: row.data['photo_front_path'] as String?,
        photoBackPath: row.data['photo_back_path'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
      );
    }).toList();
  }

  /// Get expired certifications
  Future<List<domain.Certification>> getExpiredCertifications() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final results = await _db.customSelect('''
      SELECT * FROM certifications
      WHERE expiry_date IS NOT NULL
        AND expiry_date <= ?
      ORDER BY expiry_date DESC
    ''', variables: [
      Variable.withInt(now),
    ]).get();

    return results.map((row) {
      return domain.Certification(
        id: row.data['id'] as String,
        name: row.data['name'] as String,
        agency: _parseCertificationAgency(row.data['agency'] as String),
        level: _parseCertificationLevel(row.data['level'] as String?),
        cardNumber: row.data['card_number'] as String?,
        issueDate: _parseDateTime(row.data['issue_date'] as int?),
        expiryDate: _parseDateTime(row.data['expiry_date'] as int?),
        instructorName: row.data['instructor_name'] as String?,
        instructorNumber: row.data['instructor_number'] as String?,
        photoFrontPath: row.data['photo_front_path'] as String?,
        photoBackPath: row.data['photo_back_path'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
      );
    }).toList();
  }

  /// Get certifications by agency
  Future<List<domain.Certification>> getCertificationsByAgency(
      CertificationAgency agency) async {
    final query = _db.select(_db.certifications)
      ..where((t) => t.agency.equals(agency.name))
      ..orderBy([(t) => OrderingTerm.desc(t.issueDate)]);

    final rows = await query.get();
    return rows.map(_mapRowToCertification).toList();
  }

  domain.Certification _mapRowToCertification(Certification row) {
    return domain.Certification(
      id: row.id,
      name: row.name,
      agency: _parseCertificationAgency(row.agency),
      level: _parseCertificationLevel(row.level),
      cardNumber: row.cardNumber,
      issueDate: _parseDateTime(row.issueDate),
      expiryDate: _parseDateTime(row.expiryDate),
      instructorName: row.instructorName,
      instructorNumber: row.instructorNumber,
      photoFrontPath: row.photoFrontPath,
      photoBackPath: row.photoBackPath,
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
