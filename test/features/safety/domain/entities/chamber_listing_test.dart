import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/entities/chamber_listing.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';

void main() {
  const chamber = EmergencyChamber(
    id: 'au-townsville',
    name: 'Townsville University Hospital Hyperbaric Unit',
    country: 'AU',
    phone: '+61-7-4433-1111',
    isBuiltIn: true,
  );

  test('listings compare by chamber and distance', () {
    const near = ChamberListing(chamber: chamber, distanceMeters: 1000);
    const same = ChamberListing(chamber: chamber, distanceMeters: 1000);
    const far = ChamberListing(chamber: chamber, distanceMeters: 90000);

    expect(near, same);
    expect(near, isNot(far));
  });

  test('a listing without a distance is not equal to one with a distance', () {
    // The provider rebuilds listings whenever the dive log changes, so an
    // anchor appearing or disappearing has to register as a change.
    const unplaced = ChamberListing(chamber: chamber);
    const placed = ChamberListing(chamber: chamber, distanceMeters: 0);

    expect(unplaced.distanceMeters, isNull);
    expect(unplaced, isNot(placed));
  });
}
