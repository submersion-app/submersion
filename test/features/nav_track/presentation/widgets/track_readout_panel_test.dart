import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/nav_track/presentation/widgets/track_readout_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  const data = NavTrack3dSceneData(
    times: [0, 100],
    depths: [0, 20],
    temperatures: [20, 10],
    speeds: [1.0, 3.0],
    batteryVolts: [4.0, 3.5],
    durationSeconds: 100,
    maxDepthMeters: 20,
  );

  test('rows at mid-track reflect interpolation and emphasis', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final rows = trackReadoutRows(
      lookups: TrackReadoutLookups(data),
      timestampSeconds: 50,
      units: const UnitFormatter(AppSettings()),
      l10n: l10n,
      emphasize: TrackSceneMetric.speed,
    );
    final byLabel = {for (final r in rows) r.label: r};
    expect(rows.first.label, 'Run time');
    expect(rows.first.value, '0:50');
    expect(byLabel['Depth']!.value, startsWith('10.0'));
    expect(byLabel['Temp']!.value, startsWith('15'));
    expect(byLabel['Speed']!.emphasized, isTrue);
    expect(byLabel['Depth']!.emphasized, isFalse);
    expect(byLabel.containsKey('Battery'), isTrue);
  });

  test('omits a row whose series is entirely null', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    const noBattery = NavTrack3dSceneData(
      times: [0, 10],
      depths: [0, 5],
      temperatures: [null, null],
      speeds: [null, null],
      batteryVolts: [null, null],
      durationSeconds: 10,
      maxDepthMeters: 5,
    );
    final rows = trackReadoutRows(
      lookups: TrackReadoutLookups(noBattery),
      timestampSeconds: 5,
      units: const UnitFormatter(AppSettings()),
      l10n: l10n,
    );
    final labels = rows.map((r) => r.label).toSet();
    expect(labels, isNot(contains('Temp')));
    expect(labels, isNot(contains('Speed')));
    expect(labels, isNot(contains('Battery')));
    expect(labels, contains('Depth'));
  });
}
