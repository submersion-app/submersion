/// The shape of one real dive, and nothing else about it.
///
/// This is the anonymisation boundary of the demo-data generator (issue
/// #3708): a shape has no field that can hold a date, a place, a name, a
/// note, a serial number or a source id. Only the physical traces survive:
/// depth over time, temperature, heart rate, ppO2 and cell readings,
/// setpoints, and each tank's gas, size and pressure trace. Its [id] is a
/// hash of the quantised depth curve, used to collapse the same dive
/// exported twice, never anything from the source.
library;

enum ShapeKind {
  recreational,
  deepOpenCircuit,
  multiGasDeco,
  trimix,
  ccr,
  scr,
  multiComputer,
  heartRate,
  tankPressure,
}

class ShapeSample {
  const ShapeSample({
    required this.t,
    required this.depth,
    this.temp,
    this.heartRate,
    this.ppO2,
    this.setpoint,
    this.cells,
  });

  /// Seconds from the start of the dive.
  final int t;
  final double depth;
  final double? temp;
  final int? heartRate;
  final double? ppO2;
  final double? setpoint;

  /// Oxygen cell readings in bar, in cell order.
  final List<double>? cells;

  Map<String, Object?> toJson() => {
    't': t,
    'd': depth,
    if (temp != null) 'tp': temp,
    if (heartRate != null) 'hr': heartRate,
    if (ppO2 != null) 'po': ppO2,
    if (setpoint != null) 'sp': setpoint,
    if (cells != null) 'c': cells,
  };

  factory ShapeSample.fromJson(Map<String, Object?> j) => ShapeSample(
    t: j['t']! as int,
    depth: (j['d']! as num).toDouble(),
    temp: (j['tp'] as num?)?.toDouble(),
    heartRate: j['hr'] as int?,
    ppO2: (j['po'] as num?)?.toDouble(),
    setpoint: (j['sp'] as num?)?.toDouble(),
    cells: (j['c'] as List?)?.map((c) => (c as num).toDouble()).toList(),
  );
}

class ShapeTank {
  const ShapeTank({
    required this.o2,
    required this.he,
    required this.role,
    this.volumeL,
    this.startBar,
    this.endBar,
    this.pressures = const [],
  });

  final double o2;
  final double he;

  /// The tank role's enum name (backGas, stage, deco, bailout, diluent...).
  final String role;
  final double? volumeL;
  final double? startBar;
  final double? endBar;

  /// (seconds from start, bar) pairs.
  final List<(int, double)> pressures;

  Map<String, Object?> toJson() => {
    'o2': o2,
    'he': he,
    'r': role,
    if (volumeL != null) 'v': volumeL,
    if (startBar != null) 's': startBar,
    if (endBar != null) 'e': endBar,
    if (pressures.isNotEmpty)
      'p': [
        for (final (t, bar) in pressures) [t, bar],
      ],
  };

  factory ShapeTank.fromJson(Map<String, Object?> j) => ShapeTank(
    o2: (j['o2']! as num).toDouble(),
    he: (j['he']! as num).toDouble(),
    role: j['r']! as String,
    volumeL: (j['v'] as num?)?.toDouble(),
    startBar: (j['s'] as num?)?.toDouble(),
    endBar: (j['e'] as num?)?.toDouble(),
    pressures: [
      for (final p in (j['p'] as List?) ?? const [])
        ((p as List)[0] as int, (p[1] as num).toDouble()),
    ],
  );
}

class DiveShape {
  const DiveShape({
    required this.id,
    required this.kinds,
    required this.diveMode,
    required this.sampleIntervalSec,
    required this.samples,
    required this.tanks,
    this.computerCount = 1,
  });

  final String id;
  final Set<ShapeKind> kinds;

  /// oc, ccr, scr or gauge.
  final String diveMode;
  final int sampleIntervalSec;
  final List<ShapeSample> samples;
  final List<ShapeTank> tanks;
  final int computerCount;

  double get maxDepth => samples.fold(0, (m, s) => s.depth > m ? s.depth : m);

  int get durationSec => samples.isEmpty ? 0 : samples.last.t;

  /// This dive without what the computer went on logging at the surface:
  /// samples and tank pressures more than two minutes after the last sample
  /// deeper than 1 m.
  DiveShape withoutSurfaceTail() {
    final deep = samples.where((s) => s.depth > 1);
    if (deep.isEmpty) return this;
    final end = deep.last.t + 120;
    if (durationSec <= end) return this;
    return DiveShape(
      id: id,
      kinds: kinds,
      diveMode: diveMode,
      sampleIntervalSec: sampleIntervalSec,
      samples: [
        for (final s in samples)
          if (s.t <= end) s,
      ],
      tanks: [
        for (final t in tanks)
          ShapeTank(
            o2: t.o2,
            he: t.he,
            role: t.role,
            volumeL: t.volumeL,
            startBar: t.startBar,
            endBar: t.endBar,
            pressures: [
              for (final p in t.pressures)
                if (p.$1 <= end) p,
            ],
          ),
      ],
      computerCount: computerCount,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'k': [for (final k in kinds) k.name],
    'm': diveMode,
    'i': sampleIntervalSec,
    'n': computerCount,
    's': [for (final s in samples) s.toJson()],
    'tk': [for (final t in tanks) t.toJson()],
  };

  factory DiveShape.fromJson(Map<String, Object?> j) => DiveShape(
    id: j['id']! as String,
    kinds: {
      for (final k in j['k']! as List) ShapeKind.values.byName(k as String),
    },
    diveMode: j['m']! as String,
    sampleIntervalSec: j['i']! as int,
    computerCount: (j['n'] as int?) ?? 1,
    samples: [
      for (final s in j['s']! as List)
        ShapeSample.fromJson((s as Map).cast<String, Object?>()),
    ],
    tanks: [
      for (final t in j['tk']! as List)
        ShapeTank.fromJson((t as Map).cast<String, Object?>()),
    ],
  );
}
