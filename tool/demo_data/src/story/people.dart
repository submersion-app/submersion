import 'dart:math';

import 'name_pools.dart';
import 'story_plan.dart';

/// Makes the story's fictional people, each with a full name drawn from the
/// name pool of where they live.
///
/// Names come from the factory's own random stream, seeded by a single draw
/// from the story's: whatever names are refused, the story's later draws
/// are the same. A refused or already used name is replaced from the far end
/// of that region's shuffled list, so only the refused person's name changes.
class PeopleFactory {
  PeopleFactory(Random random, {Set<String> refused = const {}})
    : _random = Random(random.nextInt(1 << 32)),
      _refused = refused;

  final Random _random;
  final Set<String> _refused;
  final _queues = <String, List<(String, String)>>{};
  final _front = <String, int>{};
  final _back = <String, int>{};
  final _used = <String>{};
  final _people = <FictionalPerson>[];

  List<FictionalPerson> get all => List.unmodifiable(_people);

  /// Keeps [name] off every generated person, for someone the story names
  /// itself (the diver's partner).
  void reserve(String name) => _used.add(name);

  FictionalPerson make(
    PersonRole role, {
    required String nameRegion,
    String? destinationKey,
    CertLevel? course,
  }) {
    final queue = _queues.putIfAbsent(nameRegion, () {
      final pool = namePools[nameRegion]!;
      return [
        for (final f in pool.first)
          for (final l in pool.last) (f, l),
      ]..shuffle(_random);
    });
    var front = _front[nameRegion] ?? 0;
    var back = _back[nameRegion] ?? queue.length - 1;
    var (first, last) = queue[front++];
    while (_refused.contains('$first $last') ||
        _used.contains('$first $last')) {
      if (back < front) throw StateError('name pool $nameRegion ran out');
      (first, last) = queue[back--];
    }
    _front[nameRegion] = front;
    _back[nameRegion] = back;
    _used.add('$first $last');
    final person = FictionalPerson(
      id: 'p-${_people.length + 1}',
      firstName: first,
      lastName: last,
      role: role,
      destinationKey: destinationKey,
      course: course,
    );
    _people.add(person);
    return person;
  }
}
