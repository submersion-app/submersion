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

  TripCylinderEvent fill(int minutes, String? bottle) => TripCylinderEvent(
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

  test('a fill stamped with seconds in the dive\'s minute counts', () {
    // The fill sheet's default "now" carries seconds; the dive's typed
    // entry does not (issue #2662).
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: {
        'a': [
          fill(0, '14'),
          fill(600, '22').copyWith(
            occurredAt: t0.add(const Duration(minutes: 600, seconds: 35)),
          ),
        ],
      },
      atMillis: at(600),
    );
    expect(labels['a']!.bottle, '22');
  });

  test('no fill before the dive, or an adjustment, names only the slot', () {
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
    // The slot's own label, which the tank line leaves out.
    expect(labels['a'], (label: 'Truck 1', bottle: 'Truck 1'));
  });

  test('a refill that names no bottle keeps the one in the slot', () {
    // The board keeps Bottle 14 through an unlabelled refill; so does the
    // dive line.
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: {
        'a': [fill(0, '14'), fill(300, null)],
      },
      atMillis: at(400),
    );
    expect(labels['a']!.bottle, '14');
  });

  test('two fills at one instant name the bottle the board does', () {
    // The fold breaks the tie on the event id, whatever order the query
    // returned the rows in: f0b after f0a.
    TripCylinderEvent at0(String id, String bottle) => TripCylinderEvent(
      id: id,
      tripCylinderId: 'a',
      kind: TripCylinderEventKind.fill,
      occurredAt: t0,
      bottleLabel: bottle,
      createdAt: t0,
      updatedAt: t0,
    );
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: {
        'a': [at0('f0b', '9'), at0('f0a', '3')],
      },
      atMillis: at(60),
    );
    expect(labels['a']!.bottle, '9');
  });
}
