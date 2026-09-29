import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_labels.dart';

void main() {
  final t0 = DateTime.utc(2026, 3, 9, 7);
  int at(int minutes) =>
      t0.add(Duration(minutes: minutes)).millisecondsSinceEpoch;
  final truck = TripCylinder(
    id: 'a',
    tripId: 't1',
    label: 'Truck 1',
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderEvent fill(int minutes, String bottle) => TripCylinderEvent(
    id: 'f$minutes',
    tripCylinderId: 'a',
    kind: TripCylinderEventKind.fill,
    occurredAt: t0.add(Duration(minutes: minutes)),
    bottleLabel: bottle,
    createdAt: t0,
    updatedAt: t0,
  );

  final swapped = {
    'a': [fill(0, '14'), fill(600, '22')],
  };

  test('a dive before the swap reads the first bottle', () {
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: swapped,
      atMillis: at(120),
    );
    expect(labels['a'], (label: 'Truck 1', bottle: '14'));
  });

  test('a dive after the swap reads the second bottle', () {
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: swapped,
      atMillis: at(700),
    );
    expect(labels['a']!.bottle, '22');
  });

  test('a fill at the dive\'s own minute counts for that dive', () {
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: swapped,
      atMillis: at(600),
    );
    expect(labels['a']!.bottle, '22');
  });

  test('no fill before the dive, or an adjustment, leaves no bottle', () {
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: {
        'a': [
          TripCylinderEvent(
            id: 'x',
            tripCylinderId: 'a',
            kind: TripCylinderEventKind.adjustment,
            occurredAt: t0,
            createdAt: t0,
            updatedAt: t0,
          ),
          fill(600, '22'),
        ],
      },
      atMillis: at(60),
    );
    expect(labels['a'], (label: 'Truck 1', bottle: null));
  });
}
