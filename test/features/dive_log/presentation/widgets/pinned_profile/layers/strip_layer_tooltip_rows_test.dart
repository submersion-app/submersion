import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_animator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_tooltip_rows.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

final _l10n = AppLocalizationsEn();
const _metric = UnitFormatter(AppSettings());

StripLine _line(
  StripLayer layer,
  double value, {
  String? label,
  bool estimated = false,
  Color color = Colors.red,
}) => StripLine(
  layer: layer,
  key: label ?? layer.name,
  color: color,
  runs: [
    [StripPoint(0, value), StripPoint(600, value)],
  ],
  min: 0,
  max: value * 2,
  estimated: estimated,
  label: label,
);

final _finding = SafetyFinding(
  id: 'f',
  diveId: 'd',
  ruleId: SafetyRuleId.rapidAscent,
  severity: SafetySeverity.significant,
  startTimestamp: 200,
  endTimestamp: 260,
  engineVersion: 1,
  createdAt: DateTime.utc(2026),
);

final _data = PinnedStripLayerData(
  lines: [
    _line(StripLayer.temperature, 20, color: Colors.orange),
    _line(StripLayer.cns, 12.34),
    _line(StripLayer.tankPressure, 150, label: 'Back gas (Air)'),
    _line(StripLayer.tankPressure, 180, label: 'Deco (EAN50)', estimated: true),
    _line(StripLayer.gtr, 1500),
    _line(StripLayer.sac, 1.2),
    _line(StripLayer.tts, 125),
    _line(StripLayer.heartRate, 88),
    _line(StripLayer.surfaceGf, 42),
  ],
  bands: [
    const StripBand(
      layer: StripLayer.phases,
      start: 0,
      end: 300,
      color: Colors.blue,
      alpha: 0.2,
      phase: DivePhase.bottom,
    ),
    StripBand(
      layer: StripLayer.safetyFindings,
      start: 200,
      end: 260,
      color: Colors.purple,
      alpha: 0.2,
      finding: _finding,
    ),
  ],
  ghosts: const [
    StripGhost(
      layer: StripLayer.plannedDepth,
      key: 'plan',
      label: 'Plan',
      color: Colors.green,
      points: [StripPoint(0, 0), StripPoint(200, 20)],
    ),
  ],
);

List<(String, String)> _rows(
  Set<StripLayer> active, {
  int seconds = 100,
  UnitFormatter units = _metric,
}) => [
  for (final r in stripLayerTooltipRows(
    layers: StripLayerState(
      data: _data,
      strengths: {for (final l in active) l: 1},
      grow: 1,
      active: active,
    ),
    cursorSeconds: seconds,
    units: units,
    l10n: _l10n,
  ))
    (r.label, r.value),
];

void main() {
  test('rows follow the active layers only, in layer order', () {
    expect(
      _rows({StripLayer.heartRate, StripLayer.temperature, StripLayer.cns}),
      [('Temp', '20°C'), ('CNS', '12.3%'), ('HR', '88 bpm')],
    );
  });

  test('temperature formats in the diver units', () {
    const imperial = UnitFormatter(
      AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
    );
    expect(_rows({StripLayer.temperature}, units: imperial), [
      ('Temp', '68°F'),
    ]);
  });

  test('each tank has a row, an estimate marked as one', () {
    expect(_rows({StripLayer.tankPressure}), [
      ('Back gas (Air)', '150 bar'),
      ('Deco (EAN50) (est.)', '180 bar'),
    ]);
  });

  test('gtr, sac, tts and surface GF read as the full chart reads them', () {
    expect(
      _rows({
        StripLayer.gtr,
        StripLayer.sac,
        StripLayer.tts,
        StripLayer.surfaceGf,
      }),
      [
        ('SrfGF', '42%'),
        ('GTR', '25 min'),
        ('SAC', '1.2 bar/min'),
        ('TTS', '3 min'),
      ],
    );
  });

  test('the SAC row is read as the full chart reads it, RMV included', () {
    final rows = stripLayerTooltipRows(
      layers: StripLayerState(
        data: _data,
        strengths: const {StripLayer.sac: 1},
        grow: 1,
        active: const {StripLayer.sac},
      ),
      cursorSeconds: 100,
      units: _metric,
      l10n: _l10n,
      sacRow: (barPerMin) => (label: 'RMV', value: '${barPerMin * 10} L/min'),
    );
    expect([for (final r in rows) (r.label, r.value)], [('RMV', '12.0 L/min')]);
  });

  test('the phase row names the phase under the cursor', () {
    expect(_rows({StripLayer.phases}), [('Phase', 'Bottom')]);
    expect(_rows({StripLayer.phases}, seconds: 400), isEmpty);
    // The last sample, where the last phase ends, is still in it.
    expect(_rows({StripLayer.phases}, seconds: 300), [('Phase', 'Bottom')]);
  });

  test('a finding row shows only inside its window', () {
    expect(_rows({StripLayer.safetyFindings}), isEmpty);
    expect(_rows({StripLayer.safetyFindings}, seconds: 230), [
      ('Safety review', 'Rapid ascents'),
    ]);
  });

  test('a ghost row reads its depth at the cursor', () {
    expect(_rows({StripLayer.plannedDepth}), [('Depth · Plan', '10.0m')]);
    expect(_rows({StripLayer.plannedDepth}, seconds: 500), isEmpty);
  });

  test('inactive layers add no row', () {
    expect(_rows({}), isEmpty);
    expect(_rows({StripLayer.media, StripLayer.annotations}), isEmpty);
  });

  test('bullets wear the layer colour', () {
    final rows = stripLayerTooltipRows(
      layers: StripLayerState(
        data: _data,
        strengths: const {StripLayer.temperature: 1},
        grow: 1,
        active: const {StripLayer.temperature},
      ),
      cursorSeconds: 100,
      units: _metric,
      l10n: _l10n,
    );
    expect(rows.single.bulletColor, Colors.orange);
  });
}
