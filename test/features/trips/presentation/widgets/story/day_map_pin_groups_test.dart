import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_map_pin_groups.dart';

void main() {
  group('groupNearbyPins', () {
    test('no pins, no groups', () {
      expect(groupNearbyPins(const [], radius: 32), isEmpty);
    });

    test('pins far apart each stand alone', () {
      final groups = groupNearbyPins(const [
        Offset(0, 0),
        Offset(100, 0),
        Offset(0, 100),
      ], radius: 32);
      expect(groups, [
        [0],
        [1],
        [2],
      ]);
    });

    test('pins on the same spot share a group', () {
      final groups = groupNearbyPins(const [
        Offset(50, 50),
        Offset(50, 50),
      ], radius: 32);
      expect(groups, [
        [0, 1],
      ]);
    });

    test('pins a few pixels apart share a group', () {
      // Two entries of one pier: different sites, near-identical pixels.
      final groups = groupNearbyPins(const [
        Offset(50, 50),
        Offset(53, 46),
      ], radius: 32);
      expect(groups, [
        [0, 1],
      ]);
    });

    test('exactly the radius apart is not a collision', () {
      final groups = groupNearbyPins(const [
        Offset(0, 0),
        Offset(32, 0),
      ], radius: 32);
      expect(groups, [
        [0],
        [1],
      ]);
    });

    test('distance is measured diagonally, not per axis', () {
      // 25 px on each axis is 35 px apart: no overlap of the dots' reach.
      final groups = groupNearbyPins(const [
        Offset(0, 0),
        Offset(25, 25),
      ], radius: 32);
      expect(groups, [
        [0],
        [1],
      ]);
    });

    test('a chain of near pins joins into one group', () {
      final groups = groupNearbyPins(const [
        Offset(0, 0),
        Offset(20, 0),
        Offset(40, 0),
      ], radius: 32);
      expect(groups, [
        [0, 1, 2],
      ]);
    });

    test('groups keep pin order, whatever order they connect in', () {
      // 0 and 2 collide, 1 stands alone; 3 joins 0's group through 2.
      final groups = groupNearbyPins(const [
        Offset(0, 0),
        Offset(200, 0),
        Offset(10, 0),
        Offset(30, 0),
      ], radius: 32);
      expect(groups, [
        [0, 2, 3],
        [1],
      ]);
    });

    test('a pin bridged to an earlier group joins under its first pin', () {
      // 3 sits between 0 and 1, which are too far apart to collide alone:
      // 3 joins 0's group first, then 1 joins it through 3.
      final groups = groupNearbyPins(const [
        Offset(0, 0),
        Offset(50, 0),
        Offset(500, 0),
        Offset(25, 0),
      ], radius: 32);
      expect(groups, [
        [0, 1, 3],
        [2],
      ]);
    });

    test('pins either side of the date line collide across the seam', () {
      // A 1000 px world: x 998 and x 3 are 5 px apart once wrapped.
      final groups = groupNearbyPins(
        const [Offset(998, 50), Offset(3, 50)],
        radius: 32,
        worldWidth: 1000,
      );
      expect(groups, [
        [0, 1],
      ]);
    });
  });
}
