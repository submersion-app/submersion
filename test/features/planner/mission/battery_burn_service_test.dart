import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/battery_burn_service.dart';

const _scooter = ScooterSpec(
  name: 'S',
  ratedSpeedMps: 0.5,
  burnTimeSeconds: 3600,
  towBurnFactor: 1.5,
);

void main() {
  const service = BatteryBurnService();

  test('cruising burns one over burn time per second', () {
    expect(
      service.burnFraction(scooter: _scooter, poweredSeconds: 1200),
      closeTo(1 / 3, 1e-9),
    );
  });

  test('towing burns at the tow factor on top of cruising', () {
    expect(
      service.burnFraction(
        scooter: _scooter,
        poweredSeconds: 1200,
        towingSeconds: 600,
      ),
      closeTo(1 / 3 + 0.25, 1e-9),
    );
  });

  test('a dead scooter burns nothing', () {
    expect(service.burnFraction(scooter: _scooter, poweredSeconds: 0), 0);
  });

  test('a scooter without a burn time is treated as flat', () {
    const dead = ScooterSpec(name: 'S', ratedSpeedMps: 0.5, burnTimeSeconds: 0);
    expect(
      service.burnFraction(scooter: dead, poweredSeconds: 60),
      double.infinity,
    );
  });

  test('the reserve check holds at the boundary and fails just past it', () {
    expect(
      service.withinReserve(burnFraction: 2 / 3, reserveFraction: 1 / 3),
      isTrue,
    );
    expect(
      service.withinReserve(burnFraction: 2 / 3 + 1e-6, reserveFraction: 1 / 3),
      isFalse,
    );
  });
}
