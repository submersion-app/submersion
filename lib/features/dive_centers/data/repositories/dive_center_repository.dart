import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/dive_center.dart' as domain;

class DiveCenterRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveCenterRepository);

  /// Get all dive centers
  Future<List<domain.DiveCenter>> getAllDiveCenters({String? diverId}) async {
    try {
      final query = _db.select(_db.diveCenters)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToDiveCenter).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all dive centers', e, stackTrace);
      rethrow;
    }
  }

  /// Get a dive center by ID
  Future<domain.DiveCenter?> getDiveCenterById(String id) async {
    try {
      final query = _db.select(_db.diveCenters)
        ..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToDiveCenter(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get dive center by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Search dive centers by name or location
  Future<List<domain.DiveCenter>> searchDiveCenters(String query) async {
    final searchTerm = '%${query.toLowerCase()}%';

    final results = await _db.customSelect('''
      SELECT * FROM dive_centers
      WHERE LOWER(name) LIKE ?
         OR LOWER(location) LIKE ?
         OR LOWER(country) LIKE ?
      ORDER BY name ASC
    ''', variables: [
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
    ],).get();

    return results.map(_mapCustomRowToDiveCenter).toList();
  }

  /// Get dive centers by country
  Future<List<domain.DiveCenter>> getDiveCentersByCountry(String country) async {
    final query = _db.select(_db.diveCenters)
      ..where((t) => t.country.equals(country))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    final rows = await query.get();
    return rows.map(_mapRowToDiveCenter).toList();
  }

  /// Get dive centers with coordinates (for map view)
  Future<List<domain.DiveCenter>> getDiveCentersWithCoordinates() async {
    final query = _db.select(_db.diveCenters)
      ..where((t) => t.latitude.isNotNull() & t.longitude.isNotNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    final rows = await query.get();
    return rows.map(_mapRowToDiveCenter).toList();
  }

  /// Create a new dive center
  Future<domain.DiveCenter> createDiveCenter(domain.DiveCenter center) async {
    try {
      _log.info('Creating dive center: ${center.name}');
      final id = center.id.isEmpty ? _uuid.v4() : center.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.into(_db.diveCenters).insert(DiveCentersCompanion(
            id: Value(id),
            diverId: Value(center.diverId),
            name: Value(center.name),
            location: Value(center.location),
            latitude: Value(center.latitude),
            longitude: Value(center.longitude),
            country: Value(center.country),
            phone: Value(center.phone),
            email: Value(center.email),
            website: Value(center.website),
            affiliations: Value(center.affiliations.join(',')),
            rating: Value(center.rating),
            notes: Value(center.notes),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),);

      _log.info('Created dive center with id: $id');
      return center.copyWith(id: id);
    } catch (e, stackTrace) {
      _log.error('Failed to create dive center: ${center.name}', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing dive center
  Future<void> updateDiveCenter(domain.DiveCenter center) async {
    try {
      _log.info('Updating dive center: ${center.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.diveCenters)..where((t) => t.id.equals(center.id)))
          .write(
        DiveCentersCompanion(
          name: Value(center.name),
          location: Value(center.location),
          latitude: Value(center.latitude),
          longitude: Value(center.longitude),
          country: Value(center.country),
          phone: Value(center.phone),
          email: Value(center.email),
          website: Value(center.website),
          affiliations: Value(center.affiliations.join(',')),
          rating: Value(center.rating),
          notes: Value(center.notes),
          updatedAt: Value(now),
        ),
      );
      _log.info('Updated dive center: ${center.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update dive center: ${center.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a dive center
  Future<void> deleteDiveCenter(String id) async {
    try {
      _log.info('Deleting dive center: $id');
      await (_db.delete(_db.diveCenters)..where((t) => t.id.equals(id))).go();
      _log.info('Deleted dive center: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete dive center: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get dive count for a dive center
  Future<int> getDiveCountForCenter(String centerId) async {
    final result = await _db.customSelect('''
      SELECT COUNT(*) as count
      FROM dives
      WHERE dive_center_id = ?
    ''', variables: [Variable.withString(centerId)],).getSingle();

    return result.data['count'] as int? ?? 0;
  }

  /// Get all unique countries
  Future<List<String>> getCountries() async {
    final results = await _db.customSelect('''
      SELECT DISTINCT country FROM dive_centers
      WHERE country IS NOT NULL AND country != ''
      ORDER BY country ASC
    ''').get();

    return results.map((row) => row.data['country'] as String).toList();
  }

  domain.DiveCenter _mapRowToDiveCenter(DiveCenter row) {
    return domain.DiveCenter(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      location: row.location,
      latitude: row.latitude,
      longitude: row.longitude,
      country: row.country,
      phone: row.phone,
      email: row.email,
      website: row.website,
      affiliations: _parseAffiliations(row.affiliations),
      rating: row.rating,
      notes: row.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  domain.DiveCenter _mapCustomRowToDiveCenter(QueryRow row) {
    return domain.DiveCenter(
      id: row.data['id'] as String,
      name: row.data['name'] as String,
      location: row.data['location'] as String?,
      latitude: (row.data['latitude'] as num?)?.toDouble(),
      longitude: (row.data['longitude'] as num?)?.toDouble(),
      country: row.data['country'] as String?,
      phone: row.data['phone'] as String?,
      email: row.data['email'] as String?,
      website: row.data['website'] as String?,
      affiliations: _parseAffiliations(row.data['affiliations'] as String?),
      rating: (row.data['rating'] as num?)?.toDouble(),
      notes: (row.data['notes'] as String?) ?? '',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
    );
  }

  List<String> _parseAffiliations(String? affiliationsStr) {
    if (affiliationsStr == null || affiliationsStr.isEmpty) {
      return [];
    }
    return affiliationsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}
