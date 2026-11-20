import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_append.dart';

/// Which slots join a board, and where, worked out without the database,
/// so a trip's editing sitting appends as the repository does (#2873).
void main() {
  final at = DateTime.utc(2026);

  TripCylinder draft(String label, {String? equipmentId}) => TripCylinder(
    id: '',
    tripId: '',
    equipmentId: equipmentId,
    label: label,
    createdAt: at,
    updatedAt: at,
  );

  test('a tank already on the board, or twice in the batch, is not added '
      'again', () {
    final added = cylindersToAppend(
      [(equipmentId: 'tank1', sortOrder: 0)],
      [
        draft('A', equipmentId: 'tank1'),
        draft('B', equipmentId: 'tank2'),
        draft('B again', equipmentId: 'tank2'),
        draft('Rental'),
      ],
      tripId: 't1',
    );

    expect([for (final c in added) c.label], ['B', 'Rental']);
  });

  test('appended slots follow the last sort order and take the trip', () {
    var n = 0;
    final added = cylindersToAppend(
      [(equipmentId: null, sortOrder: 4), (equipmentId: null, sortOrder: 1)],
      [draft('A'), draft('B')],
      tripId: 't1',
      newId: () => 'n${n++}',
    );

    expect([for (final c in added) c.sortOrder], [5, 6]);
    expect([for (final c in added) c.id], ['n0', 'n1']);
    expect({for (final c in added) c.tripId}, {'t1'});
  });

  test('with no id maker, a draft keeps its blank id for the repository to '
      'fill', () {
    final added = cylindersToAppend(const [], [draft('A')], tripId: 't1');

    expect(added.single.id, isEmpty);
    expect(added.single.sortOrder, 0);
  });
}
