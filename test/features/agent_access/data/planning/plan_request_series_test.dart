import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request_series.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

import '../../../planner/series/series_fixtures.dart';

/// A `compute_plan` request as the series the planner would hold (#4203).
void main() {
  final now = DateTime.utc(2026, 11, 14, 12);
  const ean32 = {
    'volume_l': 12,
    'start_pressure_bar': 200,
    'o2_fraction': 0.32,
  };
  const ean50 = {'volume_l': 7, 'start_pressure_bar': 200, 'o2_fraction': 0.5};
  const bottom = {'depth_m': 30, 'time_s': 1200};

  PlanRequest parse(Map<String, Object?> args) =>
      parsePlanRequest(args, settings: const PlanEngineConfig());

  ({List<Map<String, Object?>> inputs, dynamic stored}) build(
    Map<String, Object?> args, {
    SeriesFollow? follow,
  }) {
    final built = storedSeriesFor(
      parse(args),
      follow: follow,
      now: now,
      newId: idSequence(),
    );
    return (inputs: built.inputs, stored: built.stored);
  }

  test('one dive is a series of one, with its own settings', () {
    final built = build({
      'dives': [
        {
          'gf_low': 30,
          'gf_high': 70,
          'tanks': [ean32],
          'bottom': bottom,
        },
      ],
    });
    final dive = built.stored.dives.single;
    expect([dive.plan.gfLow, dive.plan.gfHigh], [30, 70]);
    expect(dive.plan.segments, hasLength(2));
    expect(dive.sourceTankIds, isEmpty);
    expect(built.stored.followedDiveId, isNull);
    expect(built.inputs.single.containsKey('carries_from_tank'), isFalse);
  });

  test('a dive that took the tanks before carries each from its own', () {
    final built = build({
      'dives': [
        {
          'tanks': [ean32, ean50],
          'bottom': bottom,
        },
        {'surface_interval_s': 3600, 'bottom': bottom},
      ],
    });
    final [first, second] = built.stored.dives;
    expect(second.sourceTankIds, {
      second.plan.tanks[0].id: first.plan.tanks[0].id,
      second.plan.tanks[1].id: first.plan.tanks[1].id,
    });
    expect(second.plan.surfaceInterval, const Duration(hours: 1));
    expect(built.inputs[1]['carries_from_tank'], [0, 1]);
  });

  test('tanks of its own carry from the same cylinder before, if any', () {
    final built = build({
      'dives': [
        {
          'tanks': [ean32, ean50],
          'bottom': bottom,
        },
        {
          'surface_interval_s': 3600,
          'tanks': [
            ean50,
            {...ean32, 'volume_l': 15},
          ],
          'bottom': bottom,
        },
      ],
    });
    final [first, second] = built.stored.dives;
    expect(second.sourceTankIds, {
      second.plan.tanks[0].id: first.plan.tanks[1].id,
    });
    expect(built.inputs[1]['carries_from_tank'], [1, null]);
  });

  test('carries_from_tank says which tank each carries from', () {
    final built = build({
      'dives': [
        {
          'tanks': [ean32, ean50],
          'bottom': bottom,
        },
        {
          'surface_interval_s': 3600,
          'tanks': [ean32],
          'carries_from_tank': [null],
          'bottom': bottom,
        },
      ],
    });
    expect(built.stored.dives[1].sourceTankIds, isEmpty);
    expect(built.inputs[1]['carries_from_tank'], [null]);
  });

  test('a dive starting at its own time has a fixed start', () {
    final built = build({
      'dives': [
        {
          'start_date_time': '2026-11-14T09:00:00Z',
          'tanks': [ean32],
          'bottom': bottom,
        },
        {'start_date_time': '2026-11-14T11:30:00Z', 'bottom': bottom},
      ],
    });
    final second = built.stored.dives[1];
    expect(second.fixedStart, isTrue);
    expect(second.plan.surfaceInterval, isNull);
    expect(second.plan.startDateTime, DateTime(2026, 11, 14, 11, 30));
  });

  group('following a logged dive', () {
    final ended = now.subtract(const Duration(hours: 3));
    final follow = SeriesFollow(
      loggedDives: [seriesLoggedDive('logged', ended)],
      endTanks: const [
        DiveTank(
          id: 'logged-50',
          volume: 7,
          gasMix: GasMix(o2: 50),
          order: 1,
          endPressure: 120,
        ),
        DiveTank(
          id: 'logged-32',
          volume: 12,
          gasMix: GasMix(o2: 32),
          order: 0,
          endPressure: 90,
        ),
      ],
    );

    test('first dive tanks carry from the logged tank of their gas', () {
      final built = build({
        'follow_dive_id': 'logged',
        'dives': [
          {
            'tanks': [ean32, ean50],
            'bottom': bottom,
          },
        ],
      }, follow: follow);
      final first = built.stored.dives.single;
      expect(built.stored.followedDiveId, 'logged');
      expect(first.sourceTankIds, {
        first.plan.tanks[0].id: 'logged-32',
        first.plan.tanks[1].id: 'logged-50',
      });
      // Logged tanks are placed in their logged order.
      expect(built.inputs.single['carries_from_tank'], [0, 1]);
    });

    test('with no interval, it starts as long after as the planner says', () {
      final built = build({
        'follow_dive_id': 'logged',
        'dives': [
          {
            'tanks': [ean32],
            'bottom': bottom,
          },
        ],
      }, follow: follow);
      expect(
        built.stored.dives.single.plan.surfaceInterval,
        const Duration(hours: 3),
      );
      expect(built.inputs.single['surface_interval_s'], 3 * 3600);
    });

    test('carries_from_tank past the logged tanks is refused', () {
      expect(
        () => build({
          'follow_dive_id': 'logged',
          'dives': [
            {
              'tanks': [ean32],
              'carries_from_tank': [2],
              'bottom': bottom,
            },
          ],
        }, follow: follow),
        throwsA(
          isA<AgentToolException>().having(
            (e) => e.details?['field'],
            'field',
            'dives[0].carries_from_tank',
          ),
        ),
      );
    });
  });
}
