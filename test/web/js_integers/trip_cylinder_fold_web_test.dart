@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

/// The trip cylinder suggestion compiled to JavaScript, where `1 << 62` is
/// zero: a slot with no fill sorted as filled at the epoch, before every
/// real fill, instead of last (issue #4194).
void main() {
  final t0 = DateTime.utc(2026, 3, 9, 8, 0);

  TripCylinderState state(String id, {DateTime? filledAt}) => TripCylinderState(
    cylinder: TripCylinder(
      id: id,
      tripId: 't1',
      label: id,
      volume: 11.1,
      workingPressure: 207,
      createdAt: t0,
      updatedAt: t0,
    ),
    pressure: 200,
    mix: const GasMix(o2: 32),
    bottleLabel: id,
    status: TripCylinderStatus.full,
    lastFill: filledAt == null
        ? null
        : TripCylinderEvent(
            id: 'f$id',
            tripCylinderId: id,
            kind: TripCylinderEventKind.fill,
            occurredAt: filledAt,
            pressure: 200,
            o2Percent: 32,
            createdAt: t0,
            updatedAt: t0,
          ),
    lastEventAt: filledAt ?? t0,
  );

  test('a slot full by gauge reading, with no fill, sorts last', () {
    final pick = suggestTripCylinder(
      states: [
        state('gauge'),
        state('filled', filledAt: t0),
      ],
      tankMix: const GasMix(o2: 32),
    );
    expect(pick!.id, 'filled');
  });
}
