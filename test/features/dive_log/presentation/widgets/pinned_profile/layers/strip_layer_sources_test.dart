import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show ChartSourceOverlay;
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_sources.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';

const _tempAuto = Color(0xFF123456);

final _style = StripLayerStyle(
  palette: ProfileMetricPalette(
    overrides: ProfileMetricColorOverrides.none,
    temperatureAuto: _tempAuto,
  ),
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(),
  tankLabel: (tank, index) => tank?.name ?? 'Tank ${index + 1}',
);

/// Ten samples, one a minute, down to 20 m and back.
final _profile = [
  for (var i = 0; i < 10; i++)
    DiveProfilePoint(
      timestamp: i * 60,
      depth: i < 5 ? i * 5.0 : (9 - i) * 5.0,
      temperature: i.isEven ? 20.0 - i : null,
      heartRate: 70 + i,
    ),
];

PinnedStripLayerData _build({
  List<DiveProfilePoint>? profile,
  ProfileAnalysis? analysis,
  EstimatedTankPressures? tanks,
  List<DiveTank> diveTanks = const [],
  List<GasSwitchWithTank> gasSwitches = const [],
  List<SacSegment>? phases,
  List<({int seconds, double depthMeters})> media = const [],
  List<ProfileEvent> annotations = const [],
  List<ProfileEvent> computerEvents = const [],
  List<SafetyFinding> findings = const [],
  ChartSourceOverlay? plan,
  List<ChartSourceOverlay> otherSources = const [],
}) => buildStripLayerData(
  StripLayerInputs(
    profile: profile ?? _profile,
    analysis: analysis,
    tanks: tanks,
    diveTanks: diveTanks,
    gasSwitches: gasSwitches,
    phases: phases,
    media: media,
    annotations: annotations,
    computerEvents: computerEvents,
    findings: findings,
    plan: plan,
    otherSources: otherSources,
  ),
  _style,
);

StripLine _line(PinnedStripLayerData data, StripLayer layer) =>
    data.lines.singleWhere((l) => l.layer == layer);

ProfileEvent _event(int seconds, ProfileEventType type) => ProfileEvent(
  id: 'e$seconds',
  diveId: 'd',
  timestamp: seconds,
  eventType: type,
  severity: EventSeverity.info,
  createdAt: DateTime.utc(2026),
);

SafetyFinding _finding(
  String id, {
  int? start,
  int? end,
  DateTime? dismissedAt,
}) => SafetyFinding(
  id: id,
  diveId: 'd',
  ruleId: SafetyRuleId.values.first,
  severity: SafetySeverity.significant,
  startTimestamp: start,
  endTimestamp: end,
  engineVersion: 1,
  dismissedAt: dismissedAt,
  createdAt: DateTime.utc(2026),
);

ChartSourceOverlay _overlay(String id, double maxDepth) => ChartSourceOverlay(
  sourceId: id,
  name: 'Computer $id',
  color: Colors.green,
  computerId: id,
  points: [
    const DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 240, depth: maxDepth),
    const DiveProfilePoint(timestamp: 540, depth: 0),
  ],
);

void main() {
  test('temperature line from profile temperatures', () {
    final line = _line(_build(), StripLayer.temperature);
    expect(line.color, _tempAuto);
    // Samples without a temperature are skipped, not drawn as gaps.
    expect(line.runs, hasLength(1));
    expect(
      [for (final p in line.runs.single) p.seconds],
      [0, 120, 240, 360, 480],
    );
    // A degree of room each side, as the full chart's temperature axis
    // has, so a steady water temperature is not drawn along the edge.
    expect(line.min, 11);
    expect(line.max, 21);
    expect(line.valueAt(60), 19);
  });

  test('no temperature samples gives no temperature line', () {
    final data = _build(
      profile: [
        for (final p in _profile)
          DiveProfilePoint(timestamp: p.timestamp, depth: p.depth),
      ],
    );
    expect(data.hasData(StripLayer.temperature), isFalse);
    expect(data.lines.where((l) => l.layer == StripLayer.temperature), isEmpty);
  });

  test('heart rate line from profile heart rate', () {
    final line = _line(_build(), StripLayer.heartRate);
    expect(line.min, 70);
    expect(line.max, 79);
  });

  test('cns line ranges 0 to the dive max', () {
    final data = _build(
      analysis: ProfileAnalysis.empty().copyWith(
        cnsCurve: [for (var i = 0; i < 10; i++) i * 2.0],
      ),
    );
    final line = _line(data, StripLayer.cns);
    expect(line.min, 0);
    expect(line.max, 18);
  });

  test('a dive with no CNS keeps its zero line at the bottom', () {
    final data = _build(
      analysis: ProfileAnalysis.empty().copyWith(
        cnsCurve: [for (var i = 0; i < 10; i++) 0.0],
      ),
    );
    final line = _line(data, StripLayer.cns);
    expect(line.min, 0);
    expect(line.max, greaterThan(line.min));
  });

  test('surface GF and TTS ranges grow past their floors, as the chart', () {
    final data = _build(
      analysis: ProfileAnalysis.empty().copyWith(
        surfaceGfCurve: [for (var i = 0; i < 10; i++) i * 20.0],
        ttsCurve: [for (var i = 0; i < 10; i++) i * 600],
      ),
    );
    expect(_line(data, StripLayer.surfaceGf).max, 180);
    expect(_line(data, StripLayer.tts).max, 5400);
  });

  test('surface GF ranges 0 to 150', () {
    final data = _build(
      analysis: ProfileAnalysis.empty().copyWith(
        surfaceGfCurve: [for (var i = 0; i < 10; i++) i * 5.0],
      ),
    );
    final line = _line(data, StripLayer.surfaceGf);
    expect((line.min, line.max), (0, 150));
  });

  test('tts and gtr lines in seconds, 0 to 3600, gtr broken at nulls', () {
    final data = _build(
      analysis: ProfileAnalysis.empty().copyWith(
        ttsCurve: [for (var i = 0; i < 10; i++) i * 30],
        gtrCurve: [null, 3000, 2900, null, 2700, 2600, 2500, null, null, 2200],
      ),
    );
    final tts = _line(data, StripLayer.tts);
    expect((tts.min, tts.max), (0, 3600));
    final gtr = _line(data, StripLayer.gtr);
    expect((gtr.min, gtr.max), (0, 3600));
    expect([for (final r in gtr.runs) r.length], [2, 3, 1]);
    expect(gtr.valueAt(180), isNull);
  });

  test('sac line draws the smoothed curve, as the full chart does', () {
    final data = _build(
      analysis: ProfileAnalysis.empty().copyWith(
        // The raw curve spikes sample to sample; the chart never draws it.
        sacCurve: [for (var i = 0; i < 10; i++) i.isEven ? 5.0 : 40.0],
        smoothedSacCurve: [for (var i = 0; i < 10; i++) 15.0 + i],
      ),
    );
    final line = _line(data, StripLayer.sac);
    expect((line.min, line.max), (15, 24));
  });

  test('sac skips the samples with no rate and takes the dive scale', () {
    final data = buildStripLayerData(
      StripLayerInputs(
        profile: _profile,
        analysis: ProfileAnalysis.empty().copyWith(
          smoothedSacCurve: [0, 0, 10, 12, 14, 16, 18, 20, 0, 0],
        ),
        sacScale: 1.5,
      ),
      _style,
    );
    final line = _line(data, StripLayer.sac);
    expect(
      [for (final p in line.runs.single) p.seconds],
      [120, 180, 240, 300, 360, 420],
    );
    expect((line.min, line.max), (15, 30));
  });

  test('tank pressure lines share one range and mark estimates', () {
    const tanks = [
      DiveTank(id: 't1', name: 'Back gas', gasMix: GasMix(o2: 21), order: 0),
      DiveTank(id: 't2', name: 'Deco', gasMix: GasMix(o2: 50), order: 1),
    ];
    final data = _build(
      diveTanks: tanks,
      tanks: const EstimatedTankPressures(
        {
          't1': [
            TankPressurePoint(tankId: 't1', timestamp: 0, pressure: 200),
            TankPressurePoint(tankId: 't1', timestamp: 540, pressure: 60),
          ],
          't2': [
            TankPressurePoint(tankId: 't2', timestamp: 0, pressure: 180),
            TankPressurePoint(tankId: 't2', timestamp: 540, pressure: 150),
          ],
        },
        {'t2'},
      ),
    );
    final lines = data.lines
        .where((l) => l.layer == StripLayer.tankPressure)
        .toList();
    expect(lines, hasLength(2));
    for (final l in lines) {
      expect((l.min, l.max), (60, 200));
    }
    expect(lines[0].label, 'Back gas');
    expect(lines[0].estimated, isFalse);
    expect(lines[0].color, GasColors.forGasMix(const GasMix(o2: 21)));
    expect(lines[1].estimated, isTrue);
    expect(lines[0].valueAt(270), 130);
  });

  test('a tank reads as the Cylinders card and full chart read it', () {
    final data = _build(
      tanks: const EstimatedTankPressures({
        't1': [
          // The transmitter paired two minutes in.
          TankPressurePoint(tankId: 't1', timestamp: 120, pressure: 200),
          TankPressurePoint(tankId: 't1', timestamp: 300, pressure: 180),
          // Two readings at one moment: the last wins, as on the chart.
          TankPressurePoint(tankId: 't1', timestamp: 300, pressure: 178),
          TankPressurePoint(tankId: 't1', timestamp: 540, pressure: 150),
        ],
      }, {}),
    );
    final line = _line(data, StripLayer.tankPressure);
    expect(line.valueAt(0), 200);
    expect(line.valueAt(300), 178);
  });

  test('a curve reads the sample at the cursor index', () {
    // Samples 4 and 5 share a timestamp.
    final profile = [
      for (var i = 0; i < 10; i++)
        DiveProfilePoint(timestamp: i < 5 ? i * 60 : (i - 1) * 60, depth: 10),
    ];
    final data = _build(
      profile: profile,
      analysis: ProfileAnalysis.empty().copyWith(
        cnsCurve: [for (var i = 0; i < 10; i++) i.toDouble()],
      ),
    );
    final line = _line(data, StripLayer.cns);
    expect(line.valueAt(240, index: 4), 4);
    expect(line.valueAt(240, index: 5), 5);
    // With no index, by time.
    expect(line.valueAt(30), 0.5);
  });

  test('tank points past the profile are dropped', () {
    final data = _build(
      tanks: const EstimatedTankPressures({
        't1': [
          TankPressurePoint(tankId: 't1', timestamp: 0, pressure: 200),
          TankPressurePoint(tankId: 't1', timestamp: 540, pressure: 60),
          TankPressurePoint(tankId: 't1', timestamp: 900, pressure: 50),
        ],
      }, {}),
    );
    final line = _line(data, StripLayer.tankPressure);
    expect(line.runs.single.last.seconds, 540);
  });

  test('a curve longer than the profile draws no further than it', () {
    final data = _build(
      analysis: ProfileAnalysis.empty().copyWith(
        cnsCurve: [for (var i = 0; i < 20; i++) i.toDouble()],
      ),
    );
    final line = _line(data, StripLayer.cns);
    expect(line.runs.single, hasLength(10));
    expect(line.max, 9);
  });

  test('gas switch tick at each switch in the new gas colour', () {
    final data = _build(
      gasSwitches: [
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 's1',
            diveId: 'd',
            timestamp: 300,
            tankId: 't2',
            createdAt: DateTime.utc(2026),
          ),
          tankName: 'Deco',
          gasMix: 'EAN50',
          o2Fraction: 0.5,
          heFraction: 0,
        ),
      ],
    );
    final tick = data.ticks.single;
    expect(tick.layer, StripLayer.gasSwitches);
    expect(tick.seconds, 300);
    expect(tick.edge, StripTickEdge.bottom);
    expect(tick.color, GasColors.forMixFraction(0.5, 0));
  });

  test('phases become bands in the consumption card colours', () {
    const segment = SacSegment(
      startTimestamp: 0,
      endTimestamp: 120,
      avgDepth: 5,
      minDepth: 0,
      maxDepth: 10,
      sacRate: 15,
      gasConsumed: 20,
      phase: DivePhase.descent,
    );
    final data = _build(
      // The same phase once per tank is drawn once.
      phases: [segment, segment],
    );
    final band = data.bands.single;
    expect(band.layer, StripLayer.phases);
    expect((band.start, band.end), (0, 120));
    expect(band.phase, DivePhase.descent);
    expect(
      band.color,
      SacSegmentColors.forPhase(DivePhase.descent, Brightness.light),
    );
  });

  test('media moments become dots', () {
    final data = _build(media: [(seconds: 200, depthMeters: 12)]);
    expect(data.dots.single.seconds, 200);
    expect(data.dots.single.depthMeters, 12);
    expect(data.hasData(StripLayer.media), isTrue);
  });

  test('annotations are solid ticks and only bookmarks join them', () {
    final data = _build(
      annotations: [_event(100, ProfileEventType.annotation)],
      computerEvents: [
        _event(200, ProfileEventType.bookmark),
        _event(300, ProfileEventType.gasSwitch),
      ],
    );
    final ticks = data.ticks
        .where((t) => t.layer == StripLayer.annotations)
        .toList();
    expect(
      [for (final t in ticks) (t.seconds, t.hollow)],
      [(100, false), (200, true)],
    );
    expect(ticks.first.edge, StripTickEdge.top);
  });

  test('findings: dismissed and start-less skipped, end-less a tick', () {
    final data = _build(
      findings: [
        _finding('window', start: 60, end: 180),
        _finding('instant', start: 300),
        _finding('timeless'),
        _finding('dismissed', start: 60, end: 90, dismissedAt: DateTime(2026)),
      ],
    );
    final band = data.bands.single;
    expect(band.layer, StripLayer.safetyFindings);
    expect((band.start, band.end), (60, 180));
    expect(band.finding?.id, 'window');
    expect(
      band.color,
      safetySeverityColor(
        SafetySeverity.significant,
        const ColorScheme.light(),
      ),
    );
    final tick = data.ticks.single;
    expect(tick.layer, StripLayer.safetyFindings);
    expect(tick.seconds, 300);
  });

  test('plan and other sources become ghosts', () {
    final data = _build(
      plan: _overlay('plan', 30),
      otherSources: [_overlay('b', 25)],
    );
    expect(
      [for (final g in data.ghosts) g.layer],
      [StripLayer.plannedDepth, StripLayer.sourceDepths],
    );
    expect(data.ghosts.last.label, 'Computer b');
    expect(data.ghostMaxDepth({StripLayer.sourceDepths}), 25);
    expect(
      data.ghostMaxDepth({StripLayer.plannedDepth, StripLayer.sourceDepths}),
      30,
    );
    expect(data.ghostMaxDepth({}), 0);
  });

  test('a long series reads its own samples, not the thinned line', () {
    // 5000 samples, past the strip's point budget, on a sawtooth the
    // thinning cannot keep whole: a scatter, not a straight ramp.
    final long = [
      for (var i = 0; i < 5000; i++)
        DiveProfilePoint(
          timestamp: i,
          depth: 10,
          temperature: 20.0 + (i * i % 17) * 0.1,
        ),
    ];
    final line = _line(_build(profile: long), StripLayer.temperature);
    expect(
      line.runs.single.length,
      lessThan(long.length),
      reason: 'the drawn line is thinned',
    );
    final misread = [
      for (var i = 0; i < long.length; i++)
        if ((line.valueAt(i)! - long[i].temperature!).abs() > 1e-9) i,
    ];
    expect(misread, isEmpty);
  });

  test('ghost points past the end of the dive are dropped', () {
    final data = _build(
      plan: const ChartSourceOverlay(
        sourceId: 'plan',
        name: 'Plan',
        color: Colors.purple,
        computerId: null,
        points: [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 300, depth: 18),
          // The plan runs on, deeper, after the dive ended at 540 s.
          DiveProfilePoint(timestamp: 900, depth: 60),
        ],
      ),
    );
    expect(data.ghosts.single.points.last.seconds, 300);
    expect(data.ghostMaxDepth({StripLayer.plannedDepth}), 18);
  });

  test('hasData is false for a layer with nothing', () {
    final data = _build();
    for (final layer in [
      StripLayer.cns,
      StripLayer.tankPressure,
      StripLayer.phases,
      StripLayer.media,
      StripLayer.safetyFindings,
      StripLayer.plannedDepth,
    ]) {
      expect(data.hasData(layer), isFalse, reason: layer.name);
    }
    expect(PinnedStripLayerData.empty.hasData(StripLayer.temperature), false);
  });

  test('line colours follow the diver palette', () {
    final data = _build(
      analysis: ProfileAnalysis.empty().copyWith(
        cnsCurve: [for (var i = 0; i < 10; i++) 1.0],
      ),
    );
    expect(
      _line(data, StripLayer.cns).color,
      _style.palette.colorOf(ProfileMetric.cns),
    );
  });
}
