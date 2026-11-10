import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// What `compute_plan` reads from an agent (issue #4203).
void main() {
  const settings = PlanEngineConfig(descentRate: 20);
  const tank = {'volume_l': 12, 'start_pressure_bar': 200, 'o2_fraction': 0.32};

  PlanRequest parse(Map<String, Object?> args) =>
      parsePlanRequest(args, settings: settings);

  Matcher refused(String field) => isA<AgentToolException>()
      .having((e) => e.code, 'code', AgentToolErrorCode.invalidArgument)
      .having((e) => e.details?['field'], 'field', field);

  group('a single dive', () {
    test('takes tanks and segments as the dive_plans family does', () {
      final request = parse({
        'dives': [
          {
            'mode': 'oc',
            'gf_low': 30,
            'gf_high': 70,
            'tanks': [tank],
            'segments': [
              {'target_depth_m': 30, 'duration_s': 1200, 'tank': 0},
            ],
          },
        ],
      });
      final dive = request.dives.single;
      expect(dive.inputs['gf_low'], 30);
      expect(dive.inputs['mode'], 'oc');
      final tanks = dive.inputs['tanks']! as List;
      expect((tanks.single as Map)['role'], 'backGas');
      expect((tanks.single as Map)['he_fraction'], 0.0);
      expect(dive.surfaceInterval, isNull);
      expect(request.followDiveId, isNull);
    });

    test('mode defaults to open circuit', () {
      final request = parse({
        'dives': [
          {
            'tanks': [tank],
            'bottom': {'depth_m': 18, 'time_s': 2400},
          },
        ],
      });
      expect(request.dives.single.inputs['mode'], 'oc');
    });

    test('bottom descends at the diver\'s rate, then holds for time_s', () {
      final request = parse({
        'dives': [
          {
            'tanks': [tank],
            'bottom': {'depth_m': 30, 'time_s': 1200},
          },
        ],
      });
      expect(request.dives.single.inputs['segments'], [
        {
          'target_depth_m': 30,
          'duration_s': 90,
          'tank': 0,
          'setpoint_bar': null,
          'split_at_configured_rate': false,
        },
        {
          'target_depth_m': 30,
          'duration_s': 1200,
          'tank': 0,
          'setpoint_bar': null,
          'split_at_configured_rate': false,
        },
      ]);
      expect(request.dives.single.inputs.containsKey('bottom'), isFalse);
    });

    test('bottom descends at the plan\'s own rate when it sets one', () {
      final request = parse({
        'dives': [
          {
            'descent_rate_m_min': 10,
            'tanks': [tank],
            'bottom': {'depth_m': 30, 'time_s': 1200, 'tank': 0},
          },
        ],
      });
      final segments = request.dives.single.inputs['segments']! as List;
      expect((segments.first as Map)['duration_s'], 180);
    });

    test('refuses a field the plan has not got', () {
      expect(
        () => parse({
          'dives': [
            {
              'tanks': [tank],
              'bottom': {'depth_m': 18, 'time_s': 60},
              'gf': 30,
            },
          ],
        }),
        throwsA(refused('dives[0].gf')),
      );
    });

    test('refuses a bad value by its path', () {
      expect(
        () => parse({
          'dives': [
            {
              'tanks': [
                {'o2_fraction': 0.8, 'he_fraction': 0.5},
              ],
              'bottom': {'depth_m': 18, 'time_s': 60},
            },
          ],
        }),
        throwsA(refused('dives[0].tanks')),
      );
    });

    test('refuses a segment naming a tank there is not', () {
      expect(
        () => parse({
          'dives': [
            {
              'tanks': [tank],
              'segments': [
                {'target_depth_m': 18, 'duration_s': 60, 'tank': 1},
              ],
            },
          ],
        }),
        throwsA(refused('dives[0].segments')),
      );
    });

    test('needs segments or bottom, not both', () {
      expect(
        () => parse({
          'dives': [
            {
              'tanks': [tank],
            },
          ],
        }),
        throwsA(refused('dives[0].segments')),
      );
      expect(
        () => parse({
          'dives': [
            {
              'tanks': [tank],
              'bottom': {'depth_m': 18, 'time_s': 60},
              'segments': [
                {'target_depth_m': 18, 'duration_s': 60, 'tank': 0},
              ],
            },
          ],
        }),
        throwsA(refused('dives[0].bottom')),
      );
    });

    test('the first dive needs tanks', () {
      expect(
        () => parse({
          'dives': [
            {
              'bottom': {'depth_m': 18, 'time_s': 60},
            },
          ],
        }),
        throwsA(refused('dives[0].tanks')),
      );
    });

    test('a first dive following nothing has no surface interval', () {
      expect(
        () => parse({
          'dives': [
            {
              'surface_interval_s': 3600,
              'tanks': [tank],
              'bottom': {'depth_m': 18, 'time_s': 60},
            },
          ],
        }),
        throwsA(refused('dives[0].surface_interval_s')),
      );
    });

    test('refuses no dives, and more than ten', () {
      expect(() => parse({'dives': []}), throwsA(refused('dives')));
      expect(() => parse({}), throwsA(refused('dives')));
      final dive = {
        'tanks': [tank],
        'surface_interval_s': 3600,
        'bottom': {'depth_m': 18, 'time_s': 60},
      };
      expect(
        () => parse({
          'dives': [for (var i = 0; i < 11; i++) dive],
        }),
        throwsA(refused('dives')),
      );
    });
  });

  group('a series', () {
    final first = {
      'gf_low': 30,
      'gf_high': 70,
      'tanks': [tank],
      'bottom': {'depth_m': 30, 'time_s': 1200},
    };

    test('a later dive takes the dive before\'s settings and tanks', () {
      final request = parse({
        'dives': [
          first,
          {
            'surface_interval_s': 5400,
            'gf_high': 85,
            'bottom': {'depth_m': 18, 'time_s': 2700},
          },
        ],
      });
      final second = request.dives[1];
      expect(second.inputs['gf_low'], 30);
      expect(second.inputs['gf_high'], 85);
      expect(second.inputs['tanks'], request.dives[0].inputs['tanks']);
      expect(second.surfaceInterval, const Duration(minutes: 90));
      expect(second.fixedStart, isFalse);
      expect(second.tanksGiven, isFalse);
    });

    test('a later dive takes the dive before\'s ascent rates and gas '
        'allowance', () {
      final request = parse({
        'dives': [
          {
            ...first,
            'intermediate_ascent_rate_m_min': 6,
            'shallow_ascent_rate_m_min': 3,
            'final_ascent_rate_m_min': 1,
            'gas_switch_stop_s': 60,
            'sac_factor': 1.5,
            'problem_solving_minutes': 0,
            'o2_narcotic': false,
          },
          {
            'surface_interval_s': 5400,
            'bottom': {'depth_m': 18, 'time_s': 2700},
          },
        ],
      });
      final second = request.dives[1].inputs;
      expect(second['intermediate_ascent_rate_m_min'], 6);
      expect(second['shallow_ascent_rate_m_min'], 3);
      expect(second['final_ascent_rate_m_min'], 1);
      expect(second['gas_switch_stop_s'], 60);
      expect(second['sac_factor'], 1.5);
      expect(second['problem_solving_minutes'], 0);
      expect(second['o2_narcotic'], false);
    });

    test('a later dive starts at its start time instead', () {
      final request = parse({
        'dives': [
          {...first, 'start_date_time': '2026-11-14T09:00:00Z'},
          {
            'start_date_time': '2026-11-14T11:00:00Z',
            'bottom': {'depth_m': 18, 'time_s': 2700},
          },
        ],
      });
      expect(request.dives[1].fixedStart, isTrue);
      expect(request.dives[1].surfaceInterval, isNull);
      expect(
        request.dives[1].inputs['start_date_time'],
        '2026-11-14T11:00:00.000Z',
      );
    });

    test('a later dive needs a surface interval or a start, not both', () {
      expect(
        () => parse({
          'dives': [
            first,
            {
              'bottom': {'depth_m': 18, 'time_s': 60},
            },
          ],
        }),
        throwsA(refused('dives[1].surface_interval_s')),
      );
      expect(
        () => parse({
          'dives': [
            first,
            {
              'surface_interval_s': 3600,
              'start_date_time': '2026-11-14T11:00:00Z',
              'bottom': {'depth_m': 18, 'time_s': 60},
            },
          ],
        }),
        throwsA(refused('dives[1].start_date_time')),
      );
    });

    test('carries_from_tank names a tank of the dive before', () {
      final request = parse({
        'dives': [
          first,
          {
            'surface_interval_s': 3600,
            'tanks': [tank, tank],
            'carries_from_tank': [0, null],
            'bottom': {'depth_m': 18, 'time_s': 60},
          },
        ],
      });
      expect(request.dives[1].carriesFromTank, [0, null]);
      expect(request.dives[1].tanksGiven, isTrue);
      expect(
        () => parse({
          'dives': [
            first,
            {
              'surface_interval_s': 3600,
              'carries_from_tank': [1],
              'bottom': {'depth_m': 18, 'time_s': 60},
            },
          ],
        }),
        throwsA(refused('dives[1].carries_from_tank')),
      );
      expect(
        () => parse({
          'dives': [
            first,
            {
              'surface_interval_s': 3600,
              'carries_from_tank': [0, 0],
              'bottom': {'depth_m': 18, 'time_s': 60},
            },
          ],
        }),
        throwsA(refused('dives[1].carries_from_tank')),
      );
    });

    test('a series following a logged dive may give the first an interval', () {
      final request = parse({
        'follow_dive_id': 'dive-1',
        'dives': [
          {...first, 'surface_interval_s': 7200},
        ],
      });
      expect(request.followDiveId, 'dive-1');
      expect(request.dives.single.surfaceInterval, const Duration(hours: 2));
    });

    test('refuses a follow_dive_id that is not text', () {
      expect(
        () => parse({
          'follow_dive_id': 3,
          'dives': [first],
        }),
        throwsA(refused('follow_dive_id')),
      );
    });
  });
}
