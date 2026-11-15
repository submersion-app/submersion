import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_picker_model.dart';

/// What each day's tile of the trip day picker draws: one shape per dive,
/// hanging from the surface, on scales shared by the whole trip.
void main() {
  final d1 = DateTime(2026, 10, 28, 9);
  final d2 = DateTime(2026, 10, 29, 9);

  TripStoryDay day(DateTime date, List<Dive> dives, {int number = 1}) =>
      TripStoryDay(
        date: DateTime(date.year, date.month, date.day),
        dayNumber: number,
        kind: TripStoryDayKind.past,
        dives: dives,
      );

  List<DiveProfilePoint> pts(List<(int, double)> p) => [
    for (final (t, d) in p) DiveProfilePoint(timestamp: t, depth: d),
  ];

  test('a recorded profile is a solid shape of its own span', () {
    final model = buildTripPickerModel(
      days: [
        day(d1, [Dive(id: 'a', dateTime: d1)]),
      ],
      profiles: {
        'a': pts([(10, 0), (600, 30), (3010, 0)]),
      },
      undivedPlanIds: const {},
    );

    final shape = model.days.single.dives.single;
    expect(shape.diveId, 'a');
    expect(shape.dashed, isFalse);
    expect(shape.points.first.seconds, 0);
    expect(shape.spanSeconds, 3000);
    expect(shape.maxDepth, 30);
  });

  test('a dive with no samples draws its estimate, dashed', () {
    final dive = Dive(
      id: 'a',
      dateTime: d1,
      maxDepth: 20,
      runtime: const Duration(minutes: 40),
    );
    final model = buildTripPickerModel(
      days: [
        day(d1, [dive]),
      ],
      profiles: {'a': const []},
      undivedPlanIds: const {},
    );

    final shape = model.days.single.dives.single;
    expect(shape.dashed, isTrue);
    expect(shape.spanSeconds, 2400);
    expect(shape.maxDepth, 20);
  });

  test('a plan nobody has dived and a draft draw dashed even with a stored '
      'profile', () {
    final profile = pts([(0, 0), (300, 18), (2400, 0)]);
    final model = buildTripPickerModel(
      days: [
        day(d1, [
          Dive(id: 'plan', dateTime: d1, isPlanned: true),
          Dive(
            id: 'draft',
            dateTime: d1.add(const Duration(hours: 2)),
            isDraft: true,
          ),
          // Mirrored from a buddy's logged dive: planned, but it happened.
          Dive(
            id: 'mirror',
            dateTime: d1.add(const Duration(hours: 4)),
            isPlanned: true,
          ),
        ]),
      ],
      profiles: {'plan': profile, 'draft': profile, 'mirror': profile},
      undivedPlanIds: const {'plan'},
    );

    expect(
      [for (final s in model.days.single.dives) s.dashed],
      [true, true, false],
    );
  });

  test('a dive with no cache entry draws nothing', () {
    final model = buildTripPickerModel(
      days: [
        day(d1, [Dive(id: 'a', dateTime: d1, maxDepth: 20)]),
      ],
      profiles: const {},
      undivedPlanIds: const {},
    );

    expect(model.days.single.dives, isEmpty);
  });

  test('a dive with no samples and nothing to estimate from draws nothing', () {
    final model = buildTripPickerModel(
      days: [
        day(d1, [Dive(id: 'a', dateTime: d1)]),
      ],
      profiles: {'a': const []},
      undivedPlanIds: const {},
    );

    expect(model.days.single.dives, isEmpty);
  });

  test('dives are in entry-time order', () {
    final profile = pts([(0, 0), (300, 18), (2400, 0)]);
    final model = buildTripPickerModel(
      days: [
        day(d1, [
          Dive(id: 'late', dateTime: d1.add(const Duration(hours: 5))),
          Dive(id: 'early', dateTime: d1),
        ]),
      ],
      profiles: {'late': profile, 'early': profile},
      undivedPlanIds: const {},
    );

    expect(
      [for (final s in model.days.single.dives) s.diveId],
      ['early', 'late'],
    );
  });

  test('both scales cover every shape, dashed ones included', () {
    final model = buildTripPickerModel(
      days: [
        day(d1, [
          Dive(id: 'a', dateTime: d1),
          Dive(id: 'b', dateTime: d1.add(const Duration(hours: 3))),
        ]),
        day(d2, [
          // The deepest shape of the trip is a plan nobody has dived.
          Dive(id: 'c', dateTime: d2, isPlanned: true),
        ], number: 2),
      ],
      profiles: {
        'a': pts([(0, 0), (300, 18), (2000, 0)]),
        'b': pts([(0, 0), (300, 25), (3000, 0)]),
        'c': pts([(0, 0), (300, 40), (2400, 0)]),
      },
      undivedPlanIds: const {'c'},
    );

    expect(model.maxDepth, 40);
    expect(model.widestDaySeconds, 5000);
    expect(model.days[0].spanSeconds, 5000);
    expect(model.days[1].spanSeconds, 2400);
  });

  test('a trip that draws nothing has zero scales', () {
    final model = buildTripPickerModel(
      days: [day(d1, const []), day(d2, const [], number: 2)],
      profiles: const {},
      undivedPlanIds: const {},
    );

    expect(model.days, hasLength(2));
    expect(model.maxDepth, 0);
    expect(model.widestDaySeconds, 0);
  });

  test('a day with no dives keeps its place', () {
    final model = buildTripPickerModel(
      days: [
        day(d1, const []),
        day(d2, [Dive(id: 'a', dateTime: d2)], number: 2),
      ],
      profiles: {
        'a': pts([(0, 0), (300, 18), (2400, 0)]),
      },
      undivedPlanIds: const {},
    );

    expect(model.days, hasLength(2));
    expect(model.days[0].dives, isEmpty);
    expect(model.days[0].date, DateTime(2026, 10, 28));
    expect(model.days[1].dives, hasLength(1));
  });

  test('a profile of one sample, or of no span, draws nothing', () {
    final model = buildTripPickerModel(
      days: [
        day(d1, [
          Dive(id: 'one', dateTime: d1),
          Dive(id: 'flat', dateTime: d1.add(const Duration(hours: 2))),
        ]),
      ],
      profiles: {
        'one': pts([(0, 12)]),
        'flat': pts([(5, 0), (5, 12)]),
      },
      undivedPlanIds: const {},
    );

    expect(model.days.single.dives, isEmpty);
  });

  test('while it is not yet known which plans were dived, a dive marked '
      'planned draws nothing; the other dives draw as usual', () {
    final profile = pts([(0, 0), (300, 18), (2400, 0)]);
    final model = buildTripPickerModel(
      days: [
        day(d1, [
          Dive(id: 'plan', dateTime: d1, isPlanned: true),
          Dive(
            id: 'draft',
            dateTime: d1.add(const Duration(hours: 3)),
            isDraft: true,
          ),
          Dive(id: 'logged', dateTime: d1.add(const Duration(hours: 6))),
        ]),
      ],
      profiles: {'plan': profile, 'draft': profile, 'logged': profile},
      undivedPlanIds: null,
    );

    final shapes = model.days.single.dives;
    expect(shapes.map((s) => s.diveId), ['draft', 'logged']);
    expect(shapes.map((s) => s.dashed), [true, false]);
  });

  group('TripPickerModelMemo', () {
    final a = Dive(id: 'a', dateTime: d1);
    final b = Dive(id: 'b', dateTime: d2);
    final days = [
      day(d1, [a]),
      day(d2, [b], number: 2),
    ];
    final profileA = pts([(0, 0), (300, 18), (2400, 0)]);

    test('hands back the same model for the same inputs', () {
      final memo = TripPickerModelMemo();
      final profiles = {'a': profileA};
      final first = memo.resolve(
        days: days,
        profiles: profiles,
        undivedPlanIds: const {},
      );
      final second = memo.resolve(
        days: days,
        profiles: profiles,
        undivedPlanIds: <String>{},
      );

      expect(second, same(first));
      expect(first.days.first.dives.single.diveId, 'a');
    });

    test('a cache that changed only for dives off this trip is the same '
        'input', () {
      final memo = TripPickerModelMemo();
      final first = memo.resolve(
        days: days,
        profiles: {'a': profileA},
        undivedPlanIds: const {},
      );
      final second = memo.resolve(
        days: days,
        // A new map, as the cache writes one: this trip's entry is the same
        // list, and another trip's dive has landed beside it.
        profiles: {'a': profileA, 'elsewhere': profileA},
        undivedPlanIds: const {},
      );

      expect(second, same(first));
    });

    test('builds again when one of the trip\'s dives gains a profile', () {
      final memo = TripPickerModelMemo();
      final first = memo.resolve(
        days: days,
        profiles: {'a': profileA},
        undivedPlanIds: const {},
      );
      final second = memo.resolve(
        days: days,
        profiles: {'a': profileA, 'b': profileA},
        undivedPlanIds: const {},
      );

      expect(second, isNot(same(first)));
      expect(second.days[1].dives.single.diveId, 'b');
    });

    test('builds again when the undived plans change, and when they become '
        'known', () {
      final memo = TripPickerModelMemo();
      final profiles = {'a': profileA};
      final unknown = memo.resolve(
        days: days,
        profiles: profiles,
        undivedPlanIds: null,
      );
      final known = memo.resolve(
        days: days,
        profiles: profiles,
        undivedPlanIds: const {},
      );
      final planned = memo.resolve(
        days: days,
        profiles: profiles,
        undivedPlanIds: const {'a'},
      );

      expect(known, isNot(same(unknown)));
      expect(planned, isNot(same(known)));
      expect(planned.days.first.dives.single.dashed, isTrue);
    });

    test('builds again for another story', () {
      final memo = TripPickerModelMemo();
      final profiles = {'a': profileA};
      final first = memo.resolve(
        days: days,
        profiles: profiles,
        undivedPlanIds: const {},
      );
      final second = memo.resolve(
        days: [days.first],
        profiles: profiles,
        undivedPlanIds: const {},
      );

      expect(second, isNot(same(first)));
      expect(second.days, hasLength(1));
    });
  });
}
