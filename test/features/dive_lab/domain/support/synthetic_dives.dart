import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

class SyntheticDive {
  SyntheticDive({
    required this.depths,
    required this.timestamps,
    required this.tanks,
    required this.switches,
    required this.tankPressures,
    required this.bottomEndIndex,
    required this.switchIndex,
  });

  final List<double> depths;
  final List<int> timestamps;
  final List<DiveTank> tanks;
  final List<ScenarioGasSwitch> switches;
  final Map<String, List<TankPressureSample>> tankPressures;

  /// Last sample of the bottom phase.
  final int bottomEndIndex;

  /// Sample at which the 50% switch happened (-1 when no deco tank).
  final int switchIndex;

  int indexAt(int seconds) => timestamps.indexOf(seconds);
}

/// Square open-circuit dive at 10 s samples: descend at 20 m/min, hold
/// [bottomMinutes] at [depth], ascend at 9 m/min, switch to 50% at 21 m when
/// [withDeco50], 3 min stop at 5 m, surface. Pressure series follow the ideal
/// gas law at [sacLpm] so a resolver that reads drop x volume / ambient /
/// minutes recovers [sacLpm] exactly.
SyntheticDive squareDive({
  double depth = 40,
  int bottomMinutes = 25,
  bool withDeco50 = true,
  bool withPressures = true,
  double sacLpm = 20,
}) {
  const step = 10;
  final depths = <double>[];
  final timestamps = <int>[];
  var t = 0;
  void add(double d) {
    depths.add(d);
    timestamps.add(t);
    t += step;
  }

  final descentSamples = (depth / 20.0 * 60 / step).round();
  for (var i = 0; i <= descentSamples; i++) {
    add(depth * i / descentSamples);
  }
  for (var i = 0; i < bottomMinutes * 60 ~/ step; i++) {
    add(depth);
  }
  final bottomEndIndex = depths.length - 1;
  var switchIndex = -1;
  var d = depth;
  while (d > 5.0 + 1e-9) {
    d = (d - 9.0 * step / 60).clamp(5.0, depth);
    add(double.parse(d.toStringAsFixed(3)));
    if (withDeco50 && switchIndex < 0 && d <= 21.0) {
      switchIndex = depths.length - 1;
    }
  }
  for (var i = 0; i < 18; i++) {
    add(5.0);
  }
  add(2.5);
  add(0.0);

  const back = DiveTank(
    id: 'back',
    volume: 24,
    startPressure: 200,
    endPressure: 80,
    gasMix: GasMix(o2: 21),
    role: TankRole.backGas,
  );
  const deco = DiveTank(
    id: 'deco50',
    volume: 11.1,
    startPressure: 200,
    endPressure: 150,
    gasMix: GasMix(o2: 50),
    role: TankRole.deco,
  );
  final tanks = [back, if (withDeco50) deco];
  final switches = [
    if (withDeco50 && switchIndex >= 0)
      ScenarioGasSwitch(timestamp: timestamps[switchIndex], tankId: 'deco50'),
  ];

  final pressures = <String, List<TankPressureSample>>{};
  if (withPressures) {
    var backBar = 200.0;
    var decoBar = 200.0;
    final backSeries = <TankPressureSample>[
      const TankPressureSample(timestamp: 0, pressureBar: 200),
    ];
    final decoSeries = <TankPressureSample>[
      if (switchIndex >= 0)
        TankPressureSample(
          timestamp: timestamps[switchIndex],
          pressureBar: 200,
        ),
    ];
    for (var i = 1; i < depths.length; i++) {
      final dt = timestamps[i] - timestamps[i - 1];
      final ambient = 1.0 + (depths[i] + depths[i - 1]) / 2 / 10.0;
      final liters = sacLpm * ambient * dt / 60.0;
      final onDeco = switchIndex >= 0 && i > switchIndex;
      if (onDeco) {
        decoBar -= liters / 11.1;
        decoSeries.add(
          TankPressureSample(timestamp: timestamps[i], pressureBar: decoBar),
        );
      } else {
        backBar -= liters / 24.0;
        backSeries.add(
          TankPressureSample(timestamp: timestamps[i], pressureBar: backBar),
        );
      }
    }
    pressures['back'] = backSeries;
    if (withDeco50) pressures['deco50'] = decoSeries;
  }

  return SyntheticDive(
    depths: depths,
    timestamps: timestamps,
    tanks: tanks,
    switches: switches,
    tankPressures: pressures,
    bottomEndIndex: bottomEndIndex,
    switchIndex: switchIndex,
  );
}

/// Multi-level variant: [depth] for [deepMinutes], then [shallowDepth] for
/// [shallowMinutes], then the same ascent as [squareDive]. No deco tank.
SyntheticDive multiLevelDive({
  double depth = 40,
  int deepMinutes = 15,
  double shallowDepth = 20,
  int shallowMinutes = 15,
}) {
  const step = 10;
  final depths = <double>[];
  final timestamps = <int>[];
  var t = 0;
  void add(double d) {
    depths.add(d);
    timestamps.add(t);
    t += step;
  }

  final descentSamples = (depth / 20.0 * 60 / step).round();
  for (var i = 0; i <= descentSamples; i++) {
    add(depth * i / descentSamples);
  }
  for (var i = 0; i < deepMinutes * 60 ~/ step; i++) {
    add(depth);
  }
  var d = depth;
  while (d > shallowDepth + 1e-9) {
    d = (d - 9.0 * step / 60).clamp(shallowDepth, depth);
    add(double.parse(d.toStringAsFixed(3)));
  }
  for (var i = 0; i < shallowMinutes * 60 ~/ step; i++) {
    add(shallowDepth);
  }
  final bottomEndIndex = depths.length - 1;
  while (d > 5.0 + 1e-9) {
    d = (d - 9.0 * step / 60).clamp(5.0, depth);
    add(double.parse(d.toStringAsFixed(3)));
  }
  for (var i = 0; i < 18; i++) {
    add(5.0);
  }
  add(2.5);
  add(0.0);
  return SyntheticDive(
    depths: depths,
    timestamps: timestamps,
    tanks: const [
      DiveTank(
        id: 'back',
        volume: 24,
        startPressure: 200,
        endPressure: 80,
        gasMix: GasMix(o2: 21),
        role: TankRole.backGas,
      ),
    ],
    switches: const [],
    tankPressures: const {},
    bottomEndIndex: bottomEndIndex,
    switchIndex: -1,
  );
}
