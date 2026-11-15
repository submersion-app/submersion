import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';

/// The landmarks the scale is drawn against (issue #4569). Multiples assume
/// Everest at 8,849 m and Challenger Deep at 10,935 m.
void main() {
  const up = VerticalLeg.ascent;
  const down = VerticalLeg.descent;

  group('landmark lists', () {
    for (final (name, list) in [
      ('ascent', ascentLandmarks),
      ('descent', descentLandmarks),
    ]) {
      test('$name is strictly ascending, named, and unique', () {
        for (var i = 1; i < list.length; i++) {
          expect(list[i].meters, greaterThan(list[i - 1].meters));
        }
        expect(list.every((l) => l.multiple == 1), isTrue);
        expect(list.map((l) => l.id).toSet(), hasLength(list.length));
      });
    }

    test('no id appears on both sides', () {
      final upIds = ascentLandmarks.map((l) => l.id).toSet();
      final downIds = descentLandmarks.map((l) => l.id).toSet();
      expect(upIds.intersection(downIds), isEmpty);
    });

    test('every id is in a list', () {
      final listed = {
        ...ascentLandmarks.map((l) => l.id),
        ...descentLandmarks.map((l) => l.id),
      };
      expect(listed, VerticalLandmarkId.values.toSet());
    });
  });

  group('nextLandmark', () {
    test('from nothing it is the smallest landmark', () {
      expect(nextLandmark(up, 0).id, VerticalLandmarkId.statueOfLiberty);
      expect(nextLandmark(down, 0).id, VerticalLandmarkId.recreationalLimit);
    });

    test('a landmark is passed at exactly its height', () {
      expect(passedLandmarks(up, 8849).last.id, VerticalLandmarkId.everest);
      final next = nextLandmark(up, 8849);
      expect(
        (next.id, next.multiple, next.meters),
        (VerticalLandmarkId.everest, 2, 17698.0),
      );
    });

    test('named landmarks interleave with multiples', () {
      expect(nextLandmark(up, 20000).id, VerticalLandmarkId.olympusMons);
      final n = nextLandmark(up, 22000);
      expect(
        (n.id, n.multiple, n.meters),
        (VerticalLandmarkId.everest, 3, 26547.0),
      );
      // 11 x Everest is 97,339 and 12 x is 106,188: the Karman line sits
      // between them.
      expect(nextLandmark(up, 98000).id, VerticalLandmarkId.karmanLine);
    });

    test('multiples continue past the last named landmark', () {
      final n = nextLandmark(up, 500000);
      expect(
        (n.id, n.multiple, n.meters),
        (VerticalLandmarkId.everest, 57, 504393.0),
      );
      final far = nextLandmark(down, 1000000);
      expect(
        (far.id, far.multiple, far.meters),
        (VerticalLandmarkId.challengerDeep, 92, 1006020.0),
      );
    });

    test('descent leans on Challenger Deep multiples', () {
      expect(nextLandmark(down, 11000).id, VerticalLandmarkId.kolaBorehole);
      final n = nextLandmark(down, 12262);
      expect(
        (n.id, n.multiple, n.meters),
        (VerticalLandmarkId.challengerDeep, 2, 21870.0),
      );
    });
  });

  group('passedLandmarks', () {
    test('nothing is passed below the smallest landmark', () {
      expect(passedLandmarks(up, 50), isEmpty);
      expect(passedLandmarks(down, 39.9), isEmpty);
    });

    test('named and multiples merge in order', () {
      final passed = passedLandmarks(up, 26547);
      final meters = passed.map((l) => l.meters).toList();
      expect(meters, orderedEquals([...meters]..sort()));
      expect(passed.where((l) => l.multiple > 1).map((l) => l.multiple), [
        2,
        3,
      ]);
      expect(passed.map((l) => l.id), contains(VerticalLandmarkId.olympusMons));
      expect(passed.last.meters, 26547);
    });

    test('a very large total gives a finite, ordered list', () {
      final passed = passedLandmarks(down, 1000000);
      // Every named descent landmark, then 2 x to 91 x Challenger Deep.
      expect(passed, hasLength(descentLandmarks.length + 90));
      expect(passed.last.multiple, 91);
    });
  });
}
