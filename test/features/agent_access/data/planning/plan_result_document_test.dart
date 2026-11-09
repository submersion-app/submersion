import 'package:flutter_test/flutter_test.dart';
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
}
