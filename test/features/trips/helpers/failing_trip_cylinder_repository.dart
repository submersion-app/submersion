import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';

/// Reads like the real repository; every delete and reorder throws, so a
/// test can check that the UI reports the failure instead of losing it.
class FailingTripCylinderRepository extends TripCylinderRepository {
  @override
  Future<void> deleteEvent(String id) async =>
      throw StateError('delete failed');

  @override
  Future<void> deleteCylinder(String id) async =>
      throw StateError('delete failed');

  @override
  Future<void> reorderCylinders(List<String> orderedIds) async =>
      throw StateError('reorder failed');
}
