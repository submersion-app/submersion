import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request_series.dart';
import 'package:submersion/features/agent_access/data/planning/plan_result_document.dart';
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// What `compute_plan` returns for each dive (issue #4203).
void main() {
  const config = PlanEngineConfig(gfLow: 30, gfHigh: 70);
  const ean21 = {'volume_l': 24, 'start_pressure_bar': 200};
  const ean50 = {
    'volume_l': 7,
    'start_pressure_bar': 200,
    'o2_fraction': 0.5,
    'role': 'deco',
  };

  List<Map<String, Object?>> compute(Map<String, Object?> args) {
    final built = storedSeriesFor(
      parsePlanRequest(args, settings: config),
      follow: null,
      now: DateTime.utc(2026, 11, 14),
    );
    final computed = computeSeriesFromStored(
      built.stored,
      follow: null,
      config: config,
    );
    return [
      for (final (i, result) in computed.results.indexed)
        planResultDocument(
          result,
          plan: built.stored.dives[i].plan,
          config: config,
          inputs: built.inputs[i],
        ),
    ];
  }

  final deco = {
    'dives': [
      {
        'gf_high': 85,
        'tanks': [ean21, ean50],
        'bottom': {'depth_m': 45, 'time_s': 1500},
      },
    ],
  };

  test('a deco dive returns its schedule, stops and gas', () {
    final doc = compute(deco).single;
    final schedule = (doc['schedule']! as List).cast<Map>();
    expect(schedule, isNotEmpty);
    expect(schedule.first['kind'], 'descent');
    // The whole-minute column adds up to the runtime beside it, as on the
    // slate.
    final minutes = schedule.fold<int>(
      0,
      (sum, row) => sum + (row['duration_min']! as int),
    );
    expect(minutes, schedule.last['runtime_min']);
    expect(doc['runtime_s'], greaterThan(1500));
    expect(doc['max_depth_m'], 45);
    expect(doc['tts_at_bottom_s'], greaterThan(0));
    final stops = (doc['stops']! as List).cast<Map>();
    expect(stops, isNotEmpty);
    expect(stops.any((s) => s['o2_fraction'] == 0.5), isTrue);
    expect(stops.every((s) => s['tank'] is int), isTrue);
    final usage = (doc['tank_usage']! as List).cast<Map>();
    expect(usage.map((u) => u['tank']), [0, 1]);
    expect(usage.first['litres_used'], greaterThan(0));
    expect(doc['cns_end_percent'], greaterThan(0));
    expect(doc['otu_total'], greaterThan(0));
    expect(doc['issues'], isA<List>());
  });

  test('a deco dive has no NDL at the bottom, and says it is in deco', () {
    final doc = compute(deco).single;
    expect(doc['ndl_at_bottom_s'], isNull);
    expect(doc['in_deco_at_bottom'], isTrue);
  });

  test('a no-stop dive gives its NDL at the bottom', () {
    final doc = compute({
      'dives': [
        {
          'tanks': [ean21],
          'bottom': {'depth_m': 12, 'time_s': 600},
        },
      ],
    }).single;
    expect(doc['ndl_at_bottom_s'], greaterThan(0));
    expect(doc['in_deco_at_bottom'], isFalse);
  });

  test('a stop row gives the travel its whole minutes fold in', () {
    final doc = compute(deco).single;
    final schedule = (doc['schedule']! as List).cast<Map>();
    final stops = schedule.where((r) => r['kind'] == 'stop').toList();
    // The first stop's travel has a row of its own; each later stop folds
    // in the leg from the stop before.
    expect(stops.first['folded_travel'], isEmpty);
    final later = stops[1];
    final travel = (later['folded_travel']! as List).cast<Map>();
    expect(travel, isNotEmpty);
    expect(travel.first['from_depth_m'], stops.first['depth_m']);
    expect(travel.last['to_depth_m'], later['depth_m']);
    expect(travel.every((t) => (t['duration_s']! as int) > 0), isTrue);
    expect(travel.every((t) => t['tank'] is int), isTrue);
    // The row's whole minutes cover the travel and the stop together.
    final previousRuntime = stops.first['runtime_s']! as int;
    expect(
      later['runtime_s'],
      previousRuntime +
          travel.fold<int>(0, (s, t) => s + (t['duration_s']! as int)) +
          (later['duration_s']! as int),
    );
    // Rows that are not stops fold in nothing.
    expect(
      schedule.where((r) => r['kind'] != 'stop'),
      everyElement(isNot(contains('folded_travel'))),
    );
  });

  test('settings say whether the plan or the diver\'s Settings set them', () {
    final doc = compute(deco).single;
    final settings = doc['effective_settings']! as Map;
    expect(settings['gf_low'], {'value': 30, 'source': 'settings'});
    expect(settings['gf_high'], {'value': 85, 'source': 'plan'});
    expect(settings['water_type'], {'value': 'salt', 'source': 'default'});
    expect(settings['ascent_rate_m_min'], {
      'value': config.ascentRate,
      'source': 'settings',
    });
    // The problem-solving allowance litres_used includes.
    expect(settings['problem_solving_minutes'], {
      'value': config.problemSolvingMinutes,
      'source': 'settings',
    });
    expect(settings['sac_factor'], {
      'value': config.buddyFactor,
      'source': 'settings',
    });
    // Off in this config: ppo2_deco_bar governs every deco gas.
    expect(settings['ppo2_deco_bands_bar'], {
      'value': null,
      'source': 'settings',
    });
    expect(settings['max_o2_depth_m'], {'value': null, 'source': 'settings'});
    expect(settings['salinity_ppt'], {'value': null, 'source': 'default'});
    // What turn pressure, minimum gas and the OTU issue are worked from.
    expect(settings.keys, containsAll(['turn_pressure_rule', 'otu_limit']));
    expect(settings['sac_stressed_l_min'], {
      'value': config.sacBottom * config.sacStressedFactor,
      'source': 'settings',
    });
    expect(settings['otu_limit'], {
      'value': config.otuLimit,
      'source': 'default',
    });
    // Open circuit: no loop settings.
    expect(settings.containsKey('setpoint_low_bar'), isFalse);
  });

  test('a loop reports the setpoints it breathes', () {
    final built = storedSeriesFor(
      parsePlanRequest({
        'dives': [
          {
            'mode': 'ccr',
            'tanks': [
              {'volume_l': 3, 'o2_fraction': 1.0, 'role': 'oxygenSupply'},
              {'volume_l': 3, 'role': 'diluent'},
            ],
            'bottom': {'depth_m': 30, 'time_s': 1200},
          },
        ],
      }, settings: config),
      follow: null,
      now: DateTime.utc(2026, 11, 14),
    );
    final settings = effectiveSettings(built.stored.dives.single.plan, config);
    expect(settings['setpoint_low_bar'], {
      'value': config.ccrSetpointLow,
      'source': 'settings',
    });
    expect(settings['setpoint_high_bar'], {
      'value': config.ccrSetpointHigh,
      'source': 'settings',
    });
  });

  test('settings name the salinity, deco layers and air breaks used', () {
    const layered = PlanEngineConfig(
      ppO2DecoBandsEnabled: true,
      ppO2DecoBand1: 1.5,
      ppO2DecoBand2: 1.55,
      ppO2DecoBand3: 1.6,
      maxO2DepthEnabled: true,
      maxO2DepthMeters: 6,
      airBreakPolicy: AirBreakPolicy(),
    );
    final built = storedSeriesFor(
      parsePlanRequest({
        'dives': [
          {
            'salinity_ppt': 10,
            'tanks': [ean21, ean50],
            'bottom': {'depth_m': 45, 'time_s': 1500},
          },
        ],
      }, settings: layered),
      follow: null,
      now: DateTime.utc(2026, 11, 14),
    );
    final settings = effectiveSettings(built.stored.dives.single.plan, layered);
    // A salinity of the plan's own overrides the water type.
    expect(settings['salinity_ppt'], {'value': 10.0, 'source': 'plan'});
    expect(settings['ppo2_deco_bands_bar'], {
      'value': [1.5, 1.55, 1.6],
      'source': 'settings',
    });
    expect(settings['max_o2_depth_m'], {'value': 6.0, 'source': 'settings'});
    expect(settings['air_breaks'], {
      'value': {'o2_s': 12 * 60, 'break_s': 6 * 60},
      'source': 'settings',
    });
  });

  test('a carried tank starts at its pressure to the tenth of a bar', () {
    final docs = compute({
      'dives': [
        {
          'tanks': [ean21],
          'bottom': {'depth_m': 30, 'time_s': 1500},
        },
        {
          'surface_interval_s': 3600,
          'bottom': {'depth_m': 18, 'time_s': 2400},
        },
      ],
    });
    final carried =
        ((docs[1]['tank_usage']! as List).single as Map)['start_pressure_bar']!
            as double;
    expect(carried, lessThan(200));
    expect(carried, double.parse(carried.toStringAsFixed(1)));
  });

  test('a water type of the plan\'s own governs while it sets no '
      'salinity', () {
    final settings =
        compute({
              'dives': [
                {
                  ...(deco['dives']! as List).single as Map,
                  'water_type': 'fresh',
                },
              ],
            }).single['effective_settings']!
            as Map;
    expect(settings['water_type'], {'value': 'fresh', 'source': 'plan'});
    expect(settings['salinity_ppt'], {'value': null, 'source': 'default'});
  });

  test('inputs are what it was computed from, in the shape a save takes', () {
    final doc = compute(deco).single;
    final inputs = doc['resolved_inputs']! as Map;
    expect(inputs['gf_high'], 85);
    expect(inputs.containsKey('gf_low'), isFalse);
    expect(inputs['segments'], hasLength(2));
  });

  test('a dive raises its issues with type, severity and where', () {
    final doc = compute({
      'dives': [
        {
          'tanks': [
            {'volume_l': 11.1, 'start_pressure_bar': 200, 'o2_fraction': 0.36},
          ],
          'bottom': {'depth_m': 32, 'time_s': 1200},
        },
      ],
    }).single;
    final issues = (doc['issues']! as List).cast<Map>();
    final ppO2 = issues.firstWhere((i) => i['type'] == 'ppO2High');
    expect(ppO2['severity'], isA<String>());
    expect(ppO2['message'], isA<String>());
    expect(ppO2['at_depth_m'], isA<num>());
  });

  test('a later dive says what it carried in', () {
    final docs = compute({
      'dives': [
        {
          'start_date_time': '2026-11-14T09:00:00Z',
          'tanks': [ean21, ean50],
          'bottom': {'depth_m': 30, 'time_s': 1500},
        },
        {
          'surface_interval_s': 5400,
          'bottom': {'depth_m': 18, 'time_s': 2400},
        },
      ],
    });
    expect(docs[0]['carried_in'], isNull);
    final carried = docs[1]['carried_in']! as Map;
    expect(carried['surface_interval_s'], 5400);
    expect(carried['cns_percent'], greaterThan(0));
    expect(carried['otu'], greaterThan(0));
    expect(carried['tissues_loaded'], isTrue);
    expect(carried['start_date_time'], startsWith('2026-11-14T'));
  });

  test('a later dive says how loaded its tissues start', () {
    Map<String, Object?> loadingAfter(int intervalS) {
      final docs = compute({
        'dives': [
          {
            'tanks': [ean21, ean50],
            'bottom': {'depth_m': 40, 'time_s': 1500},
          },
          {
            'surface_interval_s': intervalS,
            'bottom': {'depth_m': 18, 'time_s': 2400},
          },
        ],
      });
      return ((docs[1]['carried_in']! as Map)['tissue_loading']! as Map)
          .cast<String, Object?>();
    }

    final soon = loadingAfter(1800);
    final compartments = (soon['compartments']! as List).cast<Map>();
    expect(compartments, hasLength(16));
    expect(compartments.first['compartment'], 1);
    final leading = compartments.firstWhere(
      (c) => c['compartment'] == soon['leading_compartment'],
    );
    expect(leading['loading_percent'], soon['leading_loading_percent']);
    expect(
      compartments.map((c) => c['loading_percent'] as double),
      everyElement(lessThanOrEqualTo(soon['leading_loading_percent']! as num)),
    );

    // Taken as the dive starts, after the interval off-gasses it: a longer
    // interval carries in less.
    final later = loadingAfter(4 * 3600);
    expect(
      later['leading_loading_percent']! as double,
      lessThan(soon['leading_loading_percent']! as double),
    );
    expect(
      later['surface_gf_percent']! as double,
      lessThan(soon['surface_gf_percent']! as double),
    );
  });

  test('a first dive following nothing carries in no loading', () {
    expect(compute(deco).single['carried_in'], isNull);
  });
}
