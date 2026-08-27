import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

void main() {
  final file = File('test/core/deco/golden/vectors.json');
  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final cases = (doc['cases'] as List).cast<Map<String, dynamic>>();

  for (final c in cases) {
    test('golden: ${c['name']}', () {
      final envJson = c['environment'] as Map<String, dynamic>;
      final env = DiveEnvironment(
        surfacePressureBar: (envJson['surface_pressure_bar'] as num).toDouble(),
        waterDensityKgM3: (envJson['water_density_kg_m3'] as num).toDouble(),
      );
      final gf = (c['gf'] as List).cast<num>();
      final algo = BuhlmannAlgorithm(
        gfLow: gf[0] / 100.0,
        gfHigh: gf[1] / 100.0,
        environment: env,
      );

      for (final seg in (c['segments'] as List).cast<Map<String, dynamic>>()) {
        final setpoint = (seg['setpoint'] as num?)?.toDouble();
        final fN2 = (seg['f_n2'] as num).toDouble();
        final fHe = (seg['f_he'] as num).toDouble();
        algo.calculateSegment(
          depthMeters: (seg['avg_depth_m'] as num).toDouble(),
          durationSeconds: (seg['seconds'] as num).toInt(),
          fN2: fN2,
          fHe: fHe,
          breathing: setpoint != null
              ? ClosedCircuit(
                  setpoint: setpoint,
                  diluentFO2: 1.0 - fN2 - fHe,
                  diluentFHe: fHe,
                )
              : null,
        );
      }

      final expected = c['expected'] as Map<String, dynamic>;

      if (expected.containsKey('tissues_p_n2_bar')) {
        final expN2 = (expected['tissues_p_n2_bar'] as List).cast<num>();
        final expHe = (expected['tissues_p_he_bar'] as List).cast<num>();
        for (int i = 0; i < 16; i++) {
          expect(
            algo.compartments[i].currentPN2,
            closeTo(expN2[i].toDouble(), 5e-4),
            reason: '${c['name']} compartment ${i + 1} pN2',
          );
          expect(
            algo.compartments[i].currentPHe,
            closeTo(expHe[i].toDouble(), 5e-4),
            reason: '${c['name']} compartment ${i + 1} pHe',
          );
        }
      }

      if (expected.containsKey('ceiling_m')) {
        final depth = (c['segments'] as List).last['avg_depth_m'] as num;
        expect(
          algo.calculateCeiling(currentDepth: depth.toDouble()),
          closeTo((expected['ceiling_m'] as num).toDouble(), 0.5),
          reason: '${c['name']} ceiling',
        );
      }

      final schedDepth = c['schedule_from_depth_m'] as num?;
      if (schedDepth != null && expected.containsKey('stops')) {
        final gases = (c['gases'] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (g) => AvailableGas(
                fN2: (g['f_n2'] as num).toDouble(),
                fHe: (g['f_he'] as num).toDouble(),
                maxPpO2Mod: (g['mod_m'] as num).toDouble(),
              ),
            )
            .toList();
        final plan = OptimalOcAscentGas(gases: gases, maxPpO2: 1.6);
        final stops = algo.calculateDecoSchedule(
          currentDepth: schedDepth.toDouble(),
          ascentGas: plan,
        );
        final expStops = (expected['stops'] as List)
            .cast<Map<String, dynamic>>();
        expect(
          stops.length,
          expStops.length,
          reason:
              '${c['name']} stop count: '
              'got ${stops.map((s) => '${s.depthMeters}m/${s.durationSeconds}s')}',
        );
        for (int i = 0; i < expStops.length; i++) {
          expect(
            stops[i].depthMeters,
            (expStops[i]['depth_m'] as num).toDouble(),
            reason: '${c['name']} stop $i depth',
          );
          expect(
            stops[i].durationSeconds,
            closeTo((expStops[i]['seconds'] as num).toDouble(), 60),
            reason: '${c['name']} stop $i duration',
          );
        }
        final tts = algo.calculateTts(
          currentDepth: schedDepth.toDouble(),
          ascentGas: plan,
        );
        expect(
          tts,
          closeTo((expected['tts_seconds'] as num).toDouble(), 90),
          reason: '${c['name']} tts',
        );
      }
    });
  }
}
