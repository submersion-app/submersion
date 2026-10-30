import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/story/name_pools.dart';
import '../../../tool/demo_data/src/story/name_regions.dart';
import '../../../tool/demo_data/src/story/people.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';

void main() {
  List<FictionalPerson> make(PeopleFactory f) => [
    for (var i = 0; i < 40; i++)
      f.make(
        i.isEven ? PersonRole.regular : PersonRole.guide,
        nameRegion: i.isEven ? 'de' : 'id',
        destinationKey: i.isEven ? null : 'bali',
      ),
  ];

  test('every name region has a pool of at least 25 first and last names', () {
    for (final region in nameRegions) {
      final pool = namePools[region];
      expect(pool, isNotNull, reason: region);
      expect(pool!.first.toSet().length, greaterThanOrEqualTo(25));
      expect(pool.last.toSet().length, greaterThanOrEqualTo(25));
    }
  });

  test('names are unique and drawn from the region pool', () {
    final people = make(PeopleFactory(Random(1)));

    expect({for (final p in people) p.name}.length, people.length);
    expect({for (final p in people) p.id}.length, people.length);
    for (final p in people.where((p) => p.role == PersonRole.guide)) {
      expect(namePools['id']!.first, contains(p.firstName));
      expect(namePools['id']!.last, contains(p.lastName));
      expect(p.destinationKey, 'bali');
    }
  });

  test('a refused name is replaced and the other people are unchanged', () {
    final plain = make(PeopleFactory(Random(1)));
    final refused = plain[6].name;

    final again = make(PeopleFactory(Random(1), refused: {refused}));

    expect(again[6].name, isNot(refused));
    for (var i = 0; i < plain.length; i++) {
      if (i != 6) expect(again[i].name, plain[i].name, reason: 'person $i');
    }
  });

  test('the same seed gives the same people', () {
    final a = make(PeopleFactory(Random(5)));
    final b = make(PeopleFactory(Random(5)));

    expect([for (final p in a) p.name], [for (final p in b) p.name]);
  });

  test('the factory takes exactly one draw from the story random', () {
    final story = Random(9);
    PeopleFactory(story).make(PersonRole.regular, nameRegion: 'de');
    final after = story.nextInt(1000);

    final reference = Random(9)..nextInt(1 << 32);
    expect(after, reference.nextInt(1000));
  });
}
