import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';

void main() {
  const air = OpenCircuit(fO2: 0.2098);

  group('BuhlmannGf', () {
    test('reproduces raw BuhlmannAlgorithm results', () {
      final model = BuhlmannGf(gfLow: 0.4, gfHigh: 0.8);
      var state = model.initial();
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 0, endDepth: 40, durationSeconds: 133),
        air,
      );
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 40, endDepth: 40, durationSeconds: 1500),
        air,
      );
      final schedule = model.schedule(
        state,
        currentDepth: 40,
        gases: FixedAscentGas(fN2: 0.7902),
      );

      // Same dive on the raw algorithm.
      final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
      algo.calculateSegment(depthMeters: 20, durationSeconds: 133); // avg
      algo.calculateSegment(depthMeters: 40, durationSeconds: 1500);
      final rawStops = algo.calculateDecoSchedule(currentDepth: 40);
      final rawTts = algo.calculateTts(currentDepth: 40);

      expect(schedule.stops.length, rawStops.length);
      for (int i = 0; i < rawStops.length; i++) {
        expect(schedule.stops[i].depthMeters, rawStops[i].depthMeters);
        expect(schedule.stops[i].durationSeconds, rawStops[i].durationSeconds);
      }
      expect(schedule.ttsSeconds, rawTts);
    });

    test('is pure: same state in, same result out, state unchanged', () {
      final model = BuhlmannGf(gfLow: 0.4, gfHigh: 0.8);
      var state = model.initial();
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 0, endDepth: 40, durationSeconds: 133),
        air,
      );
      final s = state as BuhlmannState;
      final compsBefore = List.of(s.compartments);

      final first = model.schedule(
        state,
        currentDepth: 40,
        gases: FixedAscentGas(fN2: 0.7902),
      );
      final second = model.schedule(
        state,
        currentDepth: 40,
        gases: FixedAscentGas(fN2: 0.7902),
      );
      expect(first.ttsSeconds, second.ttsSeconds);
      expect(s.compartments, compsBefore);
    });

    test('ndlSeconds supports CCR breathing', () {
      final model = BuhlmannGf(gfLow: 0.5, gfHigh: 0.8);
      final state = model.initial();
      final ndlOc = model.ndlSeconds(state, depthMeters: 30, breathing: air);
      final ndlCcr = model.ndlSeconds(
        state,
        depthMeters: 30,
        breathing: const ClosedCircuit(setpoint: 1.3, diluentFO2: 0.21),
      );
      expect(ndlCcr, greaterThan(ndlOc));
    });

    test('ceilingMeters reports the loaded ceiling', () {
      final model = BuhlmannGf(gfLow: 0.4, gfHigh: 0.8);
      var state = model.initial();
      expect(model.ceilingMeters(state, currentDepth: 40), 0.0);
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 40, endDepth: 40, durationSeconds: 2400),
        air,
      );
      expect(model.ceilingMeters(state, currentDepth: 40), greaterThan(0));
    });
  });
}
